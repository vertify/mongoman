defmodule Mongoman.ReplicaSetTest do
  alias Mongoman.{ReplicaSet, ReplicaSetConfig}
  use ExUnit.Case

  @moduletag timeout: :infinity

  for {major, minor} = version <- [{2, 4}, {3, 2}] do
    version_str = version |> Tuple.to_list |> Enum.join(".")
    name = ExUnit.Case.register_test(__ENV__, :test, "defaults for version #{version_str}", [])
    def unquote(name)(_) do
      opts = [mongo_version: unquote(version_str)]
      replset = "default_set_#{unquote(version_str)}"
      config = ReplicaSetConfig.make(replset, 3, opts)
      cleanup = fn ->
        expected = List.duplicate(:ok, 3)
        assert ^expected = Map.values(ReplicaSet.delete_config(config))
      end

      # test starting containers from scratch
      assert {:ok, pid} = ReplicaSet.start_link(config)
      on_exit :defaults, cleanup

      # ensure node ips are available
      assert length(ReplicaSet.nodes(pid)) == 3

      # ensure we got the version we asked for
      assert {:ok, {unquote(major), unquote(minor), _}} = ReplicaSet.version(pid)

      # test killing the containers
      assert :ok = GenServer.stop(pid)
      on_exit :defaults, fn -> nil end

      # test reconfiguring from killed replica set
      assert {:ok, _} = ReplicaSet.start_link(config)
      on_exit :defaults, cleanup
    end
  end

  test "non-voting members" do
    config = ReplicaSetConfig.make("non_voting_set", 8)

    on_exit fn ->
      ReplicaSet.delete_config(config)
    end
    assert {:ok, pid} = ReplicaSet.start_link(config)

    assert length(ReplicaSet.nodes(pid)) == 8
  end
end
