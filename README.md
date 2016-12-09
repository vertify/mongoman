# Mongoman

Configures and starts local or distributed MongoDB clusters. This library is
intended to be used for tests, and is not production-ready.

Features

- [x] Configure replica sets
- [x] Starts and manages `mongod` processes through Docker: no Erlang ports
- [x] Automatically reconfigure and reuse existing Mongo containers
- [ ] ~~Configure sharded clusters~~

## Installation

Add `mongoman` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [{:mongoman, "~> 0.1.6"}]
  end
  ```

## Examples

Start a replica set named `"my_repl_set"` with 9 members:

    alias Mongoman.{ReplicaSet, ReplicaSetConfig}
    {:ok, pid} = ReplicaSet.start_link(ReplicaSetConfig.make("my_repl_set", 9))

## QA

#### The tests are slow!

Sorry, that's just how long it takes to start up and shut down all those Mongo
instances. Some of the tests need to start and stop the entire cluster
sequentially as well. Right now it takes about a minute to run on my machine.

## Prior Art

- https://github.com/christkv/mongodb-topology-manager
