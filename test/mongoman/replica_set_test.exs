defmodule Mongoman.ReplicaSetTest do
  alias Mongoman.{ReplicaSet, ReplicaSetConfig}
  use ExUnit.Case

  test "defaults" do
    config = ReplicaSetConfig.make("default_set")
    cleanup = fn ->
      expected = List.duplicate(:ok, 3)
      assert ^expected = Map.values(ReplicaSet.delete_config(config))
    end

    # test starting containers from scratch
    assert {:ok, pid} = ReplicaSet.start_link(config)
    on_exit :defaults, cleanup

    # ensure node ips are available
    assert length(ReplicaSet.nodes(pid)) == 3

    # let primary election finish
    Process.sleep(15000)

    # test killing the containers
    assert :ok = GenServer.stop(pid)
    on_exit :defaults, fn -> nil end

    # test reconfiguring from killed replica set
    assert {:ok, _} = ReplicaSet.start_link(config)
    on_exit :defaults, cleanup
  end

  test "non-voting members" do
    config = ReplicaSetConfig.make("non_voting_set", 8)

    assert {:ok, pid} = ReplicaSet.start_link(config)
    on_exit fn ->
      expected = List.duplicate(:ok, 8)
      assert ^expected = Map.values(ReplicaSet.delete_config(config))
    end

    assert length(ReplicaSet.nodes(pid)) == 8
  end
end
