defmodule Mongoman do
  @moduledoc ~S"""
  Manages `mongod` instances to configure and run replica sets.
  """

  def mongosh(js, opts \\ []) do
    port = Keyword.get(opts, :port)
    hostname = Keyword.get(opts, :hostname)
    args =
      ["--eval", to_string(js), "--quiet"] ++
      (if port != nil, do: ["--port", to_string(port)], else: []) ++
      (if hostname != nil, do: ["--host", to_string(hostname)], else: [])
    {output, exit_code} = System.cmd("mongo", args)

    if exit_code == 0 do
      {:ok, output |> String.trim_trailing}
    else
      {:error, output, exit_code}
    end
  end
end
