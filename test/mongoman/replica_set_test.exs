defmodule Mongoman.ReplicaSetTest do
  alias Mongoman.{ReplicaSet, ReplicaSetConfig, MongoCLI}
  use ExUnit.Case

  setup do
    MongoCLI.clear_docker
  end

  test "defaults" do
    config = ReplicaSetConfig.make("testset")
    assert {:ok, pid} = ReplicaSet.start_link(config)
    assert length(ReplicaSet.nodes(pid)) == 3
  end

  test "non-voting members" do
    config = ReplicaSetConfig.make("testset", 9)
    assert {:ok, pid} = ReplicaSet.start_link(config)
    assert length(ReplicaSet.nodes(pid)) == 9
  end
end
