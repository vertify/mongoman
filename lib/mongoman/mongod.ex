defmodule Mongoman.Mongod do
  @moduledoc ~S"""
  Returns arguments for starting up mongod with the given ID.
  """
  def run(mongod_id, repl_set \\ nil, opts \\ []) do
    base_path = Path.join(repl_set || "", mongod_id)
    data_path = Path.join(base_path, "data")
    log_path = Path.join(base_path, "log")
    lock_path = Path.join(data_path, "mongod.lock")

    args =
      ["--logpath", log_path, "--fork", "--dbpath", data_path] ++
      (if repl_set == nil, do: [], else: ["--replSet", repl_set]) ++
      extra_mongod_opts(opts) |> Enum.map(&String.to_charlist/1)
    with :ok <- File.mkdir_p(data_path),
         {_, 0} <- System.cmd("mongod", args),
         {:ok, lock_data} <- File.read(lock_path),
         {os_pid, _} <- Integer.parse(String.trim(lock_data)),
         do: :exec.manage(os_pid, [:monitor])
  end

  defp extra_mongod_opts([{:port, port} | rest_opts]),
    do: ["--port", to_string(port)] ++ extra_mongod_opts(rest_opts)
  defp extra_mongod_opts([_ | rest_opts]), do: extra_mongod_opts(rest_opts)
  defp extra_mongod_opts([]), do: []
end
