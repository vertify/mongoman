# Mongoman

Configures and starts local or distributed MongoDB clusters. This library can be
used just for your tests, or you can use it as a core component in your project.

Features

- [x] Configure replica sets
- [x] Starts and manages `mongod` processes through Docker: no Erlang ports
- [ ] Configure sharded clusters
- [ ] Temporarily remove a node from a replica set to rebuild big indexes (WIP)

## Installation

Add `mongoman` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [{:mongoman, "~> 0.1.6"}]
  end
  ```

## Examples

Starts a local replica set named `"my_repl_set"` with 5 members:

    config = %ReplicaSetConfig{id: "my_repl_set", members: [
      %ReplicaSetMember{id: 0},
      %ReplicaSetMember{id: 1},
      %ReplicaSetMember{id: 2},
      %ReplicaSetMember{id: 3},
      %ReplicaSetMember{id: 4}
    ]}
    {:ok, pid} = Mongoman.ReplicaSet.start_link(config)

## Similar Projects

- https://github.com/christkv/mongodb-topology-manager
