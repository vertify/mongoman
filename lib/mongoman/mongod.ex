defmodule Mongoman.Mongod do
  @moduledoc ~S"""
  Returns arguments for starting up mongod with the given ID.
  """
  def run(mongod_id, repl_set \\ nil, opts \\ []) do
    mongod = System.find_executable("mongod")
    base_path = Path.join(repl_set || "", mongod_id)
    if mongod != nil do
      data_path = Path.join(base_path, "data")
      args =
        [mongod, "--logpath", Path.join(base_path, "log"),
                 "--dbpath", data_path] ++
        (if repl_set == nil, do: [], else: ["--replSet", repl_set]) ++
        extra_mongod_opts(opts) |> Enum.map(&String.to_charlist/1)
      with :ok = File.mkdir_p(data_path),
        do: :exec.run_link(args, [:monitor])
    else
      {:error, :enoent}
    end
  end

  defp extra_mongod_opts([{:port, port} | rest_opts]),
    do: ["--port", to_string(port)] ++ extra_mongod_opts(rest_opts)
  defp extra_mongod_opts([_ | rest_opts]), do: extra_mongod_opts(rest_opts)
  defp extra_mongod_opts([]), do: []
end
