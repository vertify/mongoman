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

  defp start_nodes(ports, repl_set) when is_integer(hd(ports)) do
    nodes = Enum.reduce(ports, {[], nil}, fn
      (port, {nodes, nil}) ->
        {nodes, nil}
      (port, {_, error}) -> error
    end)
    {:ok, nodes}
  end

  defp create_replica_set({:ok, nodes}) do
    {:ok, nodes}
  end

  defp create_replica_set({:error, _} = error) do
    error
  end
end
