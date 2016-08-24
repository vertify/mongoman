defmodule Mongoman.Mongod do
  @moduledoc ~S"""
  Returns arguments for starting up mongod in the given base directory.
  """
  def args(repl_set \\ nil, opts \\ []) do
    extra_opts =
      if opts[:local] == true and opts[:port] == nil do
        Keyword.put(opts, :port, choose_port)
      else
        opts
      end |> Keyword.delete(:local)

    ["mongod", "--logpath", Path.join(repl_set || "", "log"),
               "--dbpath", Path.join(repl_set || "", "data")] ++
    (if repl_set == nil, do: [], else: ["--replSet", repl_set]) ++
    extra_mongod_opts(extra_opts)
  end

  defp extra_mongod_opts([{:port, port} | rest_opts]),
    do: ["--port", to_string(port)] ++ extra_mongod_opts(rest_opts)
  defp extra_mongod_opts([_ | rest_opts]), do: extra_mongod_opts(rest_opts)
  defp extra_mongod_opts([]), do: []

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
