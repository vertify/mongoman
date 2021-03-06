# Mongoman

Configures and starts local or distributed MongoDB clusters. This library is
intended to be used for tests, and is not production-ready.

**Features**

- [x] Configure replica sets
- [x] Starts and manages `mongod` processes through Docker: no Erlang ports
- [x] Automatically reconfigure and reuse existing Mongo containers
- [ ] ~~Configure sharded clusters~~

**Requirements**

- MongoDB 2.4 or later installed on the box in which Mongoman runs (including for tests)

## Installation

Add `mongoman` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:mongoman, "~> 0.3.6"}]
end
```

## Examples

Start a replica set named `"my_repl_set"` with 9 members:

```elixir
alias Mongoman.{ReplicaSet, ReplicaSetConfig}
{:ok, pid} = ReplicaSet.start_link(ReplicaSetConfig.make("my_repl_set", 9))
```

## Prior Art

- https://github.com/christkv/mongodb-topology-manager
