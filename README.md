# Mongoman

Configures and starts local or distributed MongoDB clusters. This library can be
used just for your tests, or you can use it as a core component in your project.

Features

- Configure replica sets, sharded clusters, or just single servers
- Starts and manages `mongod` processes locally or across several nodes for
  distributed clusters
- Allows temporarily removing a node from a replica set to rebuild large indexes

## Installation

Add `mongoman` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [{:mongoman, "~> 0.1.0"}]
  end
  ```

## Similar Projects

- https://github.com/christkv/mongodb-topology-manager
