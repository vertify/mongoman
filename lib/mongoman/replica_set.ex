defmodule Mongoman.ReplicaSet do
  use GenServer
  alias Mongoman.{MongoCLI, ReplicaSetConfig, ReplicaSetMember}

  @spec start_link(ReplicaSetConfig.t, Keyword.t) :: GenServer.on_start
  def start_link(initial_config, gen_server_opts \\ []) do
    GenServer.start_link(__MODULE__, [initial_config], gen_server_opts)
  end

  def nodes(pid) do
    GenServer.call(pid, :nodes)
  end

  def stop(pid) do
    GenServer.stop(pid)
  end

  # GenServer callbacks

  @doc false
  def init([initial_config]) do
    if discover(initial_config) do
      with {:ok, new_config} <- ensure_all_started(initial_config),
           :ok <- wait_for_all(new_config) do
        {:ok, new_config}
      else
        {:error, reason} -> {:stop, reason}
      end
    else
      with {:ok, new_config} <- ensure_all_started(initial_config),
           :ok <- wait_for_all(new_config),
           {:ok, state} <- create_replica_set(new_config) do
        {:ok, state}
      else
        {:error, reason} -> {:stop, reason}
      end
    end
  end

  def discover(config) do
    %ReplicaSetConfig{id: repl_set_name, members: members} = config
    Enum.reduce(members, false, &discover_member(repl_set_name, &1, &2))
  end

  defp discover_member(repl_set_name, member, exists?) do
    %ReplicaSetMember{id: id} = member
    container = make_name(repl_set_name, id)
    with {:ok, ips} when length(ips) > 0 <- MongoCLI.container_ip(container) do
      true
    else
      _ -> if exists? do exists? else false end
    end
  end

  @doc false
  def handle_call(:nodes, _from, %ReplicaSetConfig{members: members} = conf) do
    nodes = Enum.map(members, fn %ReplicaSetMember{host: host} -> host end)
    {:reply, nodes, conf}
  end

  defp make_name(repl_set_name, id) do
    "#{repl_set_name}#{to_string id}"
  end

  defp wait_for_all(config) do
    %ReplicaSetConfig{members: members} = config
    Enum.reduce(members, :ok, fn
      (%ReplicaSetMember{host: ip}, :ok) ->
        MongoCLI.wait_for_container(ip)
      (_, error) -> error
    end)
  end

  defp ensure_all_started(config) do
    %ReplicaSetConfig{id: repl_set_name, members: members} = config

    new_members =
      for member <- Enum.map(members, &ensure_started(&1, repl_set_name)) do
        case member do
          %Task{} = task ->
            Task.await(task, :infinity) # this can take quite a while...
          any -> any
        end
      end

    is_error = &(&1 == :error || (is_tuple(&1) && elem(&1, 0) == :error))
    errors = Enum.filter(new_members, is_error)

    if length(errors) > 0 do
      for alive_member <- new_members, !is_error.(alive_member) do
        name = make_name(repl_set_name, alive_member.id)
        # ignore the return of kill; we don't want to fail handling a failure
        MongoCLI.kill(name)
      end
      {:error, errors}
    else
      success_members = Enum.map(new_members, &elem(&1, 1))
      {:ok, %ReplicaSetConfig{config | members: success_members}}
    end
  end

  defp ensure_started(member, repl_set_name) do
    with %ReplicaSetMember{id: id} <- member,
         name = make_name(repl_set_name, id) do
      with {:ok, ips} when length(ips) > 0 <- MongoCLI.container_ip(name) do
        {:ok, %ReplicaSetMember{member | host: List.first(ips)}}
      else
        _ ->
          Task.async fn ->
            with {:ok, ips} <- MongoCLI.mongod(name, repl_set_name) do
              {:ok, %ReplicaSetMember{member | host: List.first(ips)}}
            end
          end
      end
    else
      _ -> {:error, :badarg}
    end
  end

  defp create_replica_set(%ReplicaSetConfig{members: [primary | _]} = config) do
    with %ReplicaSetMember{host: host} <- primary,
         {:ok, config_str} <- Poison.encode(config),
         {:ok, json} <- MongoCLI.mongo("rs.initiate(#{config_str})", host),
         {:ok, decoded} <- Poison.decode(json),
         :ok <- validate(decoded) do
      {:ok, config}
    end
  end

  defp validate(decoded) do
    if decoded["ok"] == 0 && decoded["code"] != 23 do
      {:error, decoded["errmsg"]}
    else
      :ok
    end
  end
end
