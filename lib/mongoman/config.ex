defmodule Mongoman.ReplicaSetConfig do
  @type t :: %__MODULE__{_id: String.t, version: non_neg_integer,
                         members: [Mongoman.ReplicaSetMember.t]}
  @derive {Poison.Encoder, except: [:version]}
  defstruct [:_id, :version, members: []]
end

defmodule Mongoman.ReplicaSetMember do
  @type t :: %__MODULE__{_id: non_neg_integer, host: String.t, pid: pid,
                         os_pid: non_neg_integer, arbiter_only: boolean,
                         build_indexes: boolean, hidden: boolean,
                         priority: non_neg_integer, tags: map, votes: 1 | 0}
  defstruct [:_id, :host, :pid, :os_pid, arbiter_only: false,
             build_indexes: true, hidden: false, priority: 1, tags: %{},
             votes: 1]
end

defimpl Poison.Encoder, for: Mongoman.ReplicaSetMember do
  def encode(member, options) do
    %Mongoman.ReplicaSetMember{_id: id,
                            host: host,
                            arbiter_only: arbiter_only,
                            build_indexes: build_indexes,
                            hidden: hidden,
                            priority: priority,
                            tags: tags,
                            votes: votes} = member
    Poison.Encoder.encode(%{_id: id,
                            host: host,
                            arbiterOnly: arbiter_only,
                            buildIndexes: build_indexes,
                            hidden: hidden,
                            priority: priority,
                            tags: tags,
                            votes: votes}, options)
  end
end
