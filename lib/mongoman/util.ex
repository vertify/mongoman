defmodule Mongoman.Util do
  def choose_port do
    try_port 27017
  end

  defp try_port(port) do
    if port_available?(port) do
      port
    else
      try_port(port + 1)
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
end
