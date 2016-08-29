defmodule Mongoman.LocalReplicaSet do
  use GenServer
  alias Mongoman
  alias Mongoman.Mongod

  def start_link(name, num_nodes, gen_server_opts \\ []) do
    GenServer.start_link(__MODULE__, [name, num_nodes], gen_server_opts)
  end

  def get_nodes(pid) do
    GenServer.call(pid, :get_nodes)
  end

  def stop(pid) do
    GenServer.stop(pid)
  end

  # GenServer callbacks

  @doc false
  def init([name, num_nodes]) do
    with {:ok, _} = result <- discover_replica_set(name) do
      result
    else
      nil ->
        with {:ok, nodes} = generate_ports(num_nodes) |> start_nodes(name),
             {:ok, _} = result <- create_replica_set(nodes) do
          result
        else
          {:error, reason} -> {:stop, reason}
        end
      {:error, reason} -> {:stop, reason}
    end
  end

  def terminate(_, nodes) do
    :ok = stop_nodes(nodes)
  end

  def handle_call(:get_nodes, _from, nodes) do
    node_addresses =
      Enum.map(nodes, fn {hostname, port, _} -> "#{hostname}:#{port}" end)
    {:reply, {:ok, node_addresses}, nodes}
  end

  defp discover_replica_set(name) do
    with {:ok, existing_ports} <- File.ls(name) do
      {existing_nodes, errors} = Enum.map(existing_ports, fn port ->
        lock = Path.join([name, port, "data/mongod.lock"])
        with {port, _} <- port |> String.trim |> Integer.parse do
          with {:ok, hostname} <- node_hostname(port),
               {:ok, pid_str} <- File.read(lock),
               {pid, _} <- pid_str |> String.trim |> Integer.parse,
               {:ok, _, id} <- :exec.manage(pid, [:monitor]) do
            {:ok, {hostname, port, id}}
          else
            _ ->
              start_node(port, name)
          end
        end
      end) |> Enum.partition(fn
        {:ok, _} -> true
        _ -> false
      end)

      if Enum.empty? errors do
        {:ok, existing_nodes}
      else
        :ok = stop_nodes(existing_nodes)
        {:error, errors}
      end
    else
      _ -> nil
    end
  end

  defp generate_ports(num_nodes, start_port \\ 27017)
  defp generate_ports(num_nodes, start_port) when num_nodes > 0 do
    next_port = choose_port(start_port)
    [next_port | generate_ports(num_nodes - 1, next_port + 1)]
  end

  defp generate_ports(0, _start_port) do
    []
  end

  defp choose_port(start_port \\ 27017) do
    if port_available?(start_port) do
      start_port
    else
      # there's no conceivable way this is going to continue forever
      choose_port(start_port + 1)
    end
  end

  defp port_available?(port) do
    case :gen_tcp.listen(port, []) do
      {:ok, port} ->
        :ok = :gen_tcp.close(port)
        true
      {:error, :eaddrinuse} ->
        false
      _ ->
        false # it's safer to assume a port is in use upon failure
    end
  end

  defp start_nodes(nodes, repl_set) do
    {errors, started_nodes} =
      nodes
      |> Enum.map(&Task.async(fn -> start_node(&1, repl_set) end))
      |> Enum.map(&Task.await(&1, 10000))
      |> Enum.partition(fn
        {:ok, _} -> false
        error -> true
      end)

    started_nodes = Enum.map(started_nodes, fn {:ok, n} -> n end)

    if Enum.empty? errors do
      {:ok, started_nodes}
    else
      :ok = stop_nodes(started_nodes)
      {:error, errors |> Enum.map(&elem(&1, 1))}
    end
  end

  defp start_node(port, repl_set) when is_integer(port) do
    with {:ok, _, id} <- Mongod.run(to_string(port), repl_set, port: port),
         {:ok, hostname} <- node_hostname(port),
         do: {:ok, {hostname, port, id}}
  end

  defp node_hostname(port) do
    Mongoman.mongosh("getHostName()", port: port)
  end

  defp create_replica_set(nodes) do
    {cmd_hostname, cmd_port, _} = hd(nodes)
    mongosh_opts = [hostname: cmd_hostname, port: cmd_port]
    with {:ok, json} <- Mongoman.mongosh("rs.initiate()", mongosh_opts),
         {:ok, decoded} <- Poison.decode(json),
         :ok <- validate(decoded),
         :ok <- add_nodes(mongosh_opts, nodes)do
      {:ok, nodes}
    else
      error ->
        :ok = stop_nodes(nodes)
        error
    end
  end

  defp validate(decoded) do
    if decoded["ok"] == 0 && decoded["code"] != 23 do
      {:error, decoded["errmsg"]}
    else
      :ok
    end
  end

  defp add_nodes(mongosh_opts, nodes) do
    if length(nodes) > 1 do
      mongosh_cmd = nodes
        |> tl
        |> Enum.map(fn {hostname, port, _} ->
             "rs.add('#{hostname}:#{port}')"
           end)
        |> Enum.join("; ")
      with {:ok, json} <- Mongoman.mongosh(mongosh_cmd, mongosh_opts),
           {:ok, %{"ok" => 1}} <- Poison.decode(json) do
        :ok
      end
    else
      :ok
    end
  end

  defp stop_nodes(nodes) do
    Enum.each(nodes, fn {_, _, node_id} ->
      :ok = :exec.stop(node_id)
    end)
    :ok
  end
end
