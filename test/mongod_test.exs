defmodule MongodTest do
  use ExUnit.Case
  alias Mongoman.Mongod

  describe "`Mongoman.Mongod.args/2`" do
    test "basic" do
      args = ["mongod", "--logpath", "log", "--dbpath", "data"]
      assert Mongod.args == args
    end

    test "with a replica set name" do
      args = ["mongod", "--logpath", "testset/log", "--dbpath", "testset/data",
              "--replSet", "testset"]
      assert Mongod.args("testset") == args
    end

    test "with `local: true` option" do
      port = Mongod.choose_port
      args = ["mongod", "--logpath", "testset/log", "--dbpath", "testset/data",
              "--replSet", "testset", "--port", to_string(port)]
      assert Mongod.args("testset", local: true) == args
    end
  end
end
