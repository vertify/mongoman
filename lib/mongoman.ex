defmodule Mongoman do
  @moduledoc ~S"""
  Manages `mongod` instances to configure and run replica sets.
  """
  alias Mongoman.ReplicaSet
  alias Mongoman.Instance

  @spec start_instance(Keyword.t) :: Instance.t
  def start_instance(_opts) do %Instance{} end

  @spec stop_instance(Instance.t) :: :ok | {:error, any}
  def stop_instance(_instance) do :ok end

  @spec list_instances :: [Instance.t]
  def list_instances do [] end

  @spec add_instance_to_replica_set(ReplicaSet.t, Instance.t) :: ReplicaSet.t
  def add_instance_to_replica_set(replica_set, _instance) do replica_set end

  def mongod_opts(dir, repl_set, opts \\ []) do
    ["mongod" |
     (if repl_set == nil do [] else ["--replSet", repl_set.name] end) ++
     ["--logpath", Path.join(dir, "log"),
      "--port", Keyword.get(opts, :port, 27017) |> to_string,
      "--dbpath", Path.join(dir, "data")]]
  end
end
