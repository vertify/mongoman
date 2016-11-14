defmodule Mongoman.ReplicaSetTest do
  alias Mongoman.{ReplicaSet, ReplicaSetConfig, ReplicaSetMember}
  use ExUnit.Case

  test "basic test" do
    config = %ReplicaSetConfig{id: "testset", members: [
      %ReplicaSetMember{id: 0},
      %ReplicaSetMember{id: 1}
    ]}
    assert {:ok, pid} = ReplicaSet.start_link(config)
    assert length(ReplicaSet.nodes(pid)) == 2
  end
end
