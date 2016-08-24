defmodule Mongoman do
  @moduledoc ~S"""
  Manages `mongod` instances to configure and run replica sets.
  """

  @spec start_local_replica_set(String.t, pos_integer) ::
          {:ok, pid} | {:error, any} | :error
  def start_local_replica_set(name, num_nodes) do
    generate_ports(num_nodes)
    |> start_nodes(name)
    |> create_replica_set
  end

  @spec start_distributed_replica_set(String.t, [node]) ::
          {:ok, pid} |
          {:error, any}
  def start_distributed_replica_set(name, nodes), do: {:error, :not_implemented}

  @spec stop_cluster(pid) :: :ok | {:error, any}
  def stop_cluster(_pid) do
    :ok
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
    {:ok, port}
  end

  defp create_replica_set({:ok, nodes}) do
    {:ok, nodes}
  end

  defp create_replica_set({:error, _} = error) do
    error
  end

  defp stop_nodes(nodes) do
    :ok
  end
end
