defmodule Mongoman.ReplicaSetTest do
  alias Mongoman.{ReplicaSet, ReplicaSetConfig, ReplicaSetMember}
  use ExUnit.Case

  test "basic test" do
    repl_set_members =
      [%ReplicaSetMember{_id: 0, host: "localhost:27018"},
       %ReplicaSetMember{_id: 1, host: "localhost:27019"}]
    config = %ReplicaSetConfig{_id: "testset", members: repl_set_members}

    {:ok, pid} = ReplicaSet.start_link(config)

    assert ["localhost:27018", "localhost:27019"] == ReplicaSet.nodes(pid)
  end
end
