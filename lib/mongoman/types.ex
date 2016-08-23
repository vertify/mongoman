defmodule Mongoman.Instance do
  @type t :: %__MODULE__{hostname: String.t, port: 0..65535}
  defstruct [:hostname, :port]
end

defmodule Mongoman.ReplicaSet do
  @type t :: %__MODULE__{name: String.t, members: [Mongoman.Instance.t]}
  defstruct [:name, :members]
end
