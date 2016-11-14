defmodule Mongoman do
  @moduledoc ~S"""
  Manages `mongod` instances to configure and run replica sets.
  """

  def mongosh(js, host) do
    args = ["--eval", to_string(js), "--quiet", "--host", to_string(host)]
    with {output, 0} <- System.cmd("mongo", args) do
      {:ok, String.trim(output)}
    else
      {error, _} -> {:error, String.trim(error)}
    end
  end
end
