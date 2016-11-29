defmodule Mongoman.ReplicaSet do
  use GenServer
  alias Mongoman.{MongoCLI, ReplicaSetConfig, ReplicaSetMember}

  @spec start_link(ReplicaSetConfig.t, Keyword.t) :: GenServer.on_start
  def start_link(initial_config, gen_server_opts \\ []) do
    GenServer.start_link(__MODULE__, [initial_config], gen_server_opts)
  end

  def nodes(pid) do
    GenServer.call(pid, :nodes, :infinity)
  end

  def stop(pid) do
    GenServer.stop(pid)
  end

  def delete(pid) do
    GenServer.call(pid, :delete, :infinity)
  end

  @doc "Execute a Mongo shell command on the replica set"
  def mongo(pid, js, opts \\ []) do
    GenServer.call(pid, {:mongo, js, opts}, :infinity)
  end

  def delete_config(config) do
    %ReplicaSetConfig{id: repl_set_name, members: members} = config
    for %ReplicaSetMember{id: id} = member <- members, into: %{} do
      name = make_name(repl_set_name, id)
      MongoCLI.kill(name)
      {member, MongoCLI.delete(name)}
    end
  end

  # GenServer callbacks

  @doc false
  def init([initial_config]) do
    if discover(initial_config) do
      with {:ok, config} <- reconfigure_members(initial_config),
           :ok <- wait_for_all(config),
           Process.sleep(15000), # wait for primary election
           {:ok, state} <- reconfig(config) do
        {:ok, state}
      else
        {:error, reason} -> {:stop, reason}
      end
    else
      with {:ok, config} <- ensure_all_started(initial_config),
           :ok <- wait_for_all(config),
           {:ok, state} <- initiate(config) do
        {:ok, state}
      else
        {:error, reason} -> {:stop, reason}
      end
    end
  end

  @doc false
  def terminate(_, config) do
    if config != nil do
      %ReplicaSetConfig{id: repl_set_name, members: members} = config
      for %ReplicaSetMember{id: id} <- members do
        name = make_name(repl_set_name, id)
        MongoCLI.kill(name)
      end
    end
  end

  defp discover(config) do
    %ReplicaSetConfig{id: repl_set_name, members: members} = config
    Enum.reduce(members, false, &discover_member(repl_set_name, &1, &2))
  end

  defp discover_member(repl_set_name, %ReplicaSetMember{id: id}, exists?) do
    if exists? do
      exists?
    else
      MongoCLI.discover(make_name(repl_set_name, id))
    end
  end

  defp reconfigure_members(config) do
    %ReplicaSetConfig{id: repl_set_name, members: members} = config

    new_members_result =
      members
      |> Enum.reduce({:ok, []}, &reconfigure_member(repl_set_name, &1, &2))

    with {:ok, new_members} <- new_members_result do
      {:ok, %ReplicaSetConfig{config | members: new_members}}
    end
  end

  defp reconfigure_member(repl_set_name, member, {:ok, members}) do
    %ReplicaSetMember{id: id} = member
    name = make_name(repl_set_name, id)
    with {:ok, ips} <- MongoCLI.reconfigure(name, repl_set_name) do
      {:ok, [%ReplicaSetMember{member | host: List.first(ips)} | members]}
    end
  end
  defp reconfigure_member(_, _, acc), do: acc

  @doc false
  def handle_call(:nodes, _from, %ReplicaSetConfig{members: members} = conf) do
    nodes = Enum.map(members, fn %ReplicaSetMember{host: host} ->
      "#{host}:27017"
    end)
    {:reply, nodes, conf}
  end

  @doc false
  def handle_call({:mongo, js, opts}, _from, config) do
    {:reply, MongoCLI.mongo(js, Keyword.put(opts, :replica_set, config)), config}
  end

  @doc false
  def handle_call(:delete, _, config) do
    {:stop, :shutdown, delete_config(config), nil}
  end

  defp make_name(repl_set_name, id) do
    "#{repl_set_name}_#{to_string id}"
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
      for {:ok, alive_member} <- new_members do
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

  defp initiate(%ReplicaSetConfig{members: [primary | _]} = config) do
    with %ReplicaSetMember{host: host} <- primary,
         {:ok, config_str} <- Poison.encode(config),
         {:ok, result} <- MongoCLI.mongo("rs.initiate(#{config_str})", host: host),
         :ok <- validate(result) do
      {:ok, config}
    end
  end

  defp existing_member_map(host) do
    with {:ok, config} <- MongoCLI.mongo("rs.conf()", host: host) do
      members =
        Enum.map(config["members"], fn member ->
          {member["host"], member["_id"]}
        end)
        |> Enum.into(%{})
      {:ok, members}
    end
  end

  defp transform_config(config, existing_member_map) do
    %ReplicaSetConfig{members: members} = config

    new_members_result =
      members
      |> Enum.reduce({:ok, []}, &transform_member(existing_member_map, &1, &2))

    with {:ok, new_members} <- new_members_result do
      {:ok, %ReplicaSetConfig{config | members: new_members}}
    end
  end

  def transform_member(existing_member_map, member, {:ok, members}) do
    host = if String.ends_with?(member.host, ":27017") do
      member.host
    else
      "#{member.host}:27017"
    end
    new_id = existing_member_map[host]
    if new_id != nil do
      {:ok, [%ReplicaSetMember{member | id: new_id} | members]}
    else
      {:error, :configuration_changed}
    end
  end
  def transform_member(_, _, {:error, _} = error), do: error

  defp reconfig(config) do
    with %ReplicaSetMember{host: host} <- find_primary(config),
         # this pulls down the existing config
         {:ok, existing_member_map} <- existing_member_map(host),
         # and uses it to maintain the same pairing between ID and host in the
         # new config
         {:ok, config} <- transform_config(config, existing_member_map),
         {:ok, config_str} <- Poison.encode(config),
         # upload and validate the new config
         {:ok, result} <- MongoCLI.mongo("rs.reconfig(#{config_str})", host: host),
         :ok <- validate(result) do
      {:ok, config}
    else
      nil -> {:error, :primary_not_found}
      error -> error
    end
  end

  defp find_primary(config) do
    %ReplicaSetConfig{members: members} = config
    Enum.reduce(members, nil, &primary?/2)
  end

  defp primary?(member, nil) do
    with %ReplicaSetMember{host: host} <- member,
         {:ok, %{"ismaster" => true}} <- MongoCLI.mongo("db.isMaster()", host: host) do
      member
    else
      _ -> nil
    end
  end
  defp primary?(_, primary), do: primary

  defp validate(decoded) do
    if decoded["ok"] == 0 && decoded["code"] != 23 do
      {:error, decoded["errmsg"]}
    else
      :ok
    end
  end
end
