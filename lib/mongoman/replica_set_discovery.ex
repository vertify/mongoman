defmodule Mongoman.ReplicaSetDiscovery do
  alias Mongoman.{ReplicaSetConfig, ReplicaSetMember}
  def run(%ReplicaSetConfig{members: members} = config) do
    {exists?, new_members} =
      Enum.reduce(members, {false, []}, fn (member, {exists?, members}) ->
        %ReplicaSetMember{_id: id, host: host} = member
        %URI{port: port, host: hostname} = URI.parse("tcp://#{host}")

        if local_host? hostname do
          case pid_listening_on(port) do
            {:ok, os_pid} ->
              {:ok, pid, _} = :exec.manage(os_pid, [:monitor])
              new_member = %ReplicaSetMember{member | os_pid: os_pid, pid: pid}
              {true, [new_member | members]}
            :error ->
              {exists?, [member | members]}
          end
        else
          IO.puts :stderr, "Remote members not supported, ignoring #{host}"
          {exists?, members}
        end
      end)
    {exists?, %{config | members: new_members}}
  end

  defp local_host?(hostname) do
    hostname_cl = String.to_charlist(hostname)
    with {:ok, my_addrs} <- local_addrs,
         {:ok, {_, _, _, _, _, addrs}} <- :inet.gethostbyname(hostname_cl) do
      Enum.any?(addrs, &(&1 in my_addrs))
    else
      _ -> false
    end
  end

  defp local_addrs do
    with {:ok, ifaddrs} <- :inet.getifaddrs do
      {:ok, inet4addrs(ifaddrs)}
    end
  end

  defp inet4addrs(ifaddrs) do
    ifaddrs
    |> Keyword.values
    |> Enum.flat_map(fn info ->
      info
      |> Enum.map(fn
        {:addr, {_, _, _, _} = addr} ->
          addr
        _ ->
          nil
      end)
      |> Enum.filter(&(&1 != nil))
    end)
  end

  defp pid_listening_on(port) do
    pid_cmd = "JSON.stringify([db.serverStatus().pid.floatApprox])"
    with {:ok, pid_str} <- Mongoman.mongosh(pid_cmd, port: port),
         {:ok, [os_pid]} <- Poison.decode(pid_str) do
      {:ok, os_pid}
    else
      _ -> :error
    end
  end
end
