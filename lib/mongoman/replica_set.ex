defmodule Mongoman.LocalReplicaSet do
  use GenServer
  alias Mongoman
  alias Mongoman.Mongod

  def start_link(name, num_nodes, gen_server_opts \\ []) do
    GenServer.start_link(__MODULE__, [name, num_nodes], gen_server_opts)
  end

  # GenServer callbacks

  @doc false
  def init([name, num_nodes]) do
    case generate_ports(num_nodes)
         |> start_nodes(name) do
      {:ok, nodes} -> create_replica_set(nodes)
      {:error, reason} -> {:stop, reason}
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
    result = Enum.reduce(nodes, {[], nil}, fn
      (my_node, {mongods, nil}) ->
        case start_node(my_node, repl_set) do
          {:ok, my_mongod} ->
            {[my_mongod | mongods], nil}
          {:error, error} ->
            {nodes, error}
        end
      (port, error) -> error
    end)

    case result do
      {nodes, nil} ->
        {:ok, nodes |> Enum.reverse}
      {started_nodes, error} ->
        :ok = stop_nodes(started_nodes)
        {:error, error}
    end
  end

  defp start_node(port, repl_set) when is_integer(port) do
    with {:ok, _, id} <- Mongod.run(to_string(port), repl_set, port: port),
         {:ok, hostname} <- Mongoman.mongosh("getHostName()", port: port),
         do: {:ok, {hostname, port, id}}
  end

  defp create_replica_set(nodes) do
    {cmd_hostname, cmd_port, _} = hd(nodes)
    mongosh_opts = [hostname: cmd_hostname, port: cmd_port]
    with {:ok, json} <- Mongoman.mongosh("rs.initiate()", mongosh_opts),
         {:ok, decoded} <- Poison.decode(json),
         :ok = validate(decoded),
         :ok = add_nodes(mongosh_opts, nodes)do
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
      Enum.reduce(tl(nodes), :ok, fn
        ({hostname, port, _}, :ok) ->
          with {:ok, json} <- Mongoman.mongosh("rs.add('#{hostname}:#{port}')",
                                               mongosh_opts),
               {:ok, %{"ok" => 1}} = Poison.decode(json) do
            :ok
          end
        (_, error) ->
          error
      end)
    else
      :ok
    end
  end

  defp stop_nodes(nodes) do
    :ok
  end
end