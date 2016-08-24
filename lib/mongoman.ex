defmodule Mongoman do
  @moduledoc ~S"""
  Manages `mongod` instances to configure and run replica sets.
  """

  @spec start_local_replica_set(String.t, pos_integer) ::
          {:ok, pid} |
          {:error, any}
  def start_local_replica_set(name, num_nodes) do
    {:ok, nil}
  end

  @spec start_distributed_replica_set(String.t, [node]) ::
          {:ok, pid} |
          {:error, any}
  def start_distributed_replica_set(name, nodes), do: {:error, :not_implemented}

  @spec stop_cluster(pid) :: :ok | {:error, any}
  def stop_cluster(_cluster_pid) do
    :ok
  end
end
