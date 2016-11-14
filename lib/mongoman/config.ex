defmodule Mongoman.ReplicaSetConfig do
  @type t :: %__MODULE__{id: String.t, version: non_neg_integer,
                         members: [Mongoman.ReplicaSetMember.t]}
  defstruct [:id, version: 1, members: []]
end

defmodule Mongoman.ReplicaSetMember do
  @type t :: %__MODULE__{id: non_neg_integer, host: String.t}
  defstruct [:id, :host]
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
