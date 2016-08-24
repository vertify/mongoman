defmodule Mongoman.Mongod do
  @moduledoc ~S"""
  Returns arguments for starting up mongod in the given base directory.
  """
  def args(repl_set \\ nil, opts \\ []) do
    ["mongod", "--logpath", Path.join(repl_set || "", "log"),
               "--dbpath", Path.join(repl_set || "", "data")] ++
    (if repl_set == nil, do: [], else: ["--replSet", repl_set]) ++
    extra_mongod_opts(opts)
  end

  defp extra_mongod_opts([{:port, port} | rest_opts]),
    do: ["--port", to_string(port)] ++ extra_mongod_opts(rest_opts)
  defp extra_mongod_opts([_ | rest_opts]), do: extra_mongod_opts(rest_opts)
  defp extra_mongod_opts([]), do: []
end
