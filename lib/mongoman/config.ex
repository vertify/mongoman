defmodule Mongoman.ReplicaSetMember do
  @type t :: %__MODULE__{id: non_neg_integer,
                         host: String.t | nil,
                         votes: non_neg_integer,
                         priority: non_neg_integer}
  defstruct [:id, :host, votes: 1, priority: 1]
end

defmodule Mongoman.ReplicaSetConfig do
  @type t :: %__MODULE__{id: String.t, version: non_neg_integer,
                         members: [Mongoman.ReplicaSetMember.t]}
  defstruct [:id, version: 1, members: []]

  @spec make(String.t, 1..50) :: t
  def make(repl_set_name, num_members \\ 3) do
    %__MODULE__{id: repl_set_name,
                version: 1,
                members: for i <- 1..num_members do
                  if i < 8 do
                    %Mongoman.ReplicaSetMember{id: i - 1}
                  else
                    %Mongoman.ReplicaSetMember{id: i - 1, votes: 0, priority: 0}
                  end
                end}
  end
end

defimpl Poison.Encoder, for: Mongoman.ReplicaSetMember do
  def encode(member, options) do
    member
    |> Map.from_struct
    |> Map.delete(:id)
    |> Map.put(:_id, member.id)
    |> Poison.Encoder.encode(options)
  end
end

defimpl Poison.Encoder, for: Mongoman.ReplicaSetConfig do
  def encode(config, options) do
    config
    |> Map.from_struct
    |> Map.delete(:id)
    |> Map.put(:_id, config.id)
    |> Poison.Encoder.encode(options)
  end
end
