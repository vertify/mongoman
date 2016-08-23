defmodule Mongoman.Util do
  def port_available?(port) do
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
