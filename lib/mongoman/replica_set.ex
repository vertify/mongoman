defmodule Mongoman.ReplicaSet do
  use GenServer
  alias Mongoman.{Mongod, ReplicaSetConfig, ReplicaSetMember,
                  ReplicaSetDiscovery}

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
    with {true, config} <- ReplicaSetDiscovery.run(initial_config) do
      ensure_all_started(config)
    else
      {false, config} ->
        with {:ok, new_config} <- ensure_all_started(config) do
          create_replica_set(new_config)
        else
          {:error, reason} -> {:stop, reason}
        end
      {:error, reason} -> {:stop, reason}
    end
  end

  @doc false
  def handle_call(:nodes, _from, %ReplicaSetConfig{members: members} = conf) do
    nodes = Enum.map(members, fn %ReplicaSetMember{host: host} -> host end)
    {:reply, nodes, conf}
  end

  defp ensure_all_started(config) do
    %ReplicaSetConfig{_id: repl_set_name, members: members} = config
    Enum.reduce(members, {:ok, %ReplicaSetConfig{config | members: []}}, fn
      (member, {:ok, %ReplicaSetConfig{members: members} = config}) ->
        case ensure_started(member, repl_set_name) do
          {:ok, new_member} ->
            {:ok, %ReplicaSetConfig{config | members: [new_member | members]}}
          error ->
            error
        end

      (_, error) ->
        error
    end)
  end

  defp ensure_started(%ReplicaSetMember{os_pid: nil} = member, repl_set_name) do
    with %ReplicaSetMember{_id: id, host: host} <- member,
         %URI{port: port} <- URI.parse("tcp://#{host}"),
         {:ok, pid, os_pid} <- Mongod.run(id, repl_set_name, port: port) do
      {:ok, %ReplicaSetMember{member | os_pid: os_pid, pid: pid}}
    else
      {:error, _} = error -> error
      _ -> :error
    end
  end
  defp ensure_started(member, _), do: {:ok, member}

  defp create_replica_set(%ReplicaSetConfig{} = config) do
    with {:ok, opts} <- choose_primary(config),
         {:ok, config_str} <- Poison.encode(config),
         {:ok, json} <- Mongoman.mongosh("rs.initiate(#{config_str})", opts),
         {:ok, decoded} <- Poison.decode(json),
         :ok <- validate(decoded) do
      {:ok, config}
    end
  end

  defp choose_primary(%ReplicaSetConfig{members: [member | _]}) do
    with %ReplicaSetMember{host: host} <- member,
         %URI{host: hostname, port: port} <- URI.parse("tcp://#{host}") do
      {:ok, [hostname: hostname, port: port || 27017]}
    else
      _ -> :error
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
