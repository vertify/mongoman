defmodule Mongoman.Mongod do
  @moduledoc ~S"""
  Returns arguments for starting up mongod with the given ID.
  """
  def run(mongod_id, repl_set_name, opts \\ []) do
    base_path_components =
      [Application.get_env(:mongoman, :root_path), repl_set_name, mongod_id]
      |> Enum.map(&to_string/1)
    base_path = Path.join(base_path_components)
    data_path = Path.join(base_path, "data")
    log_path = Path.join(base_path, "log")
    lock_path = Path.join(data_path, "mongod.lock")

    args =
      ["--logpath", log_path, "--fork", "--dbpath", data_path,
       "--replSet", repl_set_name] ++ extra_mongod_opts(opts)

    # TODO: wait for mongod to start listening
    with :ok <- File.mkdir_p(data_path),
         {_, 0} <- System.cmd("mongod", Enum.map(args, &String.to_charlist/1)),
         {:ok, lock_data} <- File.read(lock_path),
         {os_pid, _} <- Integer.parse(String.trim(lock_data)),
         do: :exec.manage(os_pid, [:monitor])
  end

  defp extra_mongod_opts([{:port, port} | rest_opts]),
    do: ["--port", to_string(port)] ++ extra_mongod_opts(rest_opts)
  defp extra_mongod_opts([_ | rest_opts]), do: extra_mongod_opts(rest_opts)
  defp extra_mongod_opts([]), do: []
end
