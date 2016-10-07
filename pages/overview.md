# Mongoman Overview

Mongoman allows you to manage a MongoDB cluster through Elixir. It can handle
starting MongoDB nodes across nodes and configuring them to work together. It
can also find and configure itself from an existing MongoDB cluster.

## Specifying Nodes

You can specify nodes as either local or remote. Local nodes are specified by an
integer, which represents the port on which to run the MongoDB instance. Remote
nodes are specified by a binary, which represents the hostname where the MongoDB
instance should run.

## Updating the Config

It's possible to update the Mongoman config to permanently add or remove nodes
from the replica set. Note that dynamically added nodes will have to be
rediscovered through the config of static nodes. If all the static nodes die, or
there is a network partition that separates a set of dynamic nodes from the list
of static nodes while Mongoman is disconnected, it's possible for Mongoman to
lose a node. To prevent this, use a sufficiently large number of static nodes in
your configuration.

## Starting a Remote MongoDB Instance

To start a remote MongoDB instance as part of a Mongoman replica set, first the
nodes intended for use by Mongoman should have an erlang node running called
"mongo". This will be used to manage the MongoDB process on that erlang node.
Other than that, all that's needed is the external hostname of the node to add
it to the cluster.

## How Discovery Works

To discover the configuration of an existing MongoDB cluster, Mongoman will
attempt to connect to the databases at the specified locations. If Mongoman is
able to find the address of a MongoDB database, it pulls down the replica set
configuration as JSON and finds all the other MongoDB hosts. It then connects to
the erlang node called "mongo" on each of these instances, which represents the
process managing the MongoDB instance on that node, except for any local
addresses, which will be managed locally.
