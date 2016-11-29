defmodule Mongoman.MongoCLI do
  def mongod(name, repl_set_name) do
    with {:ok, _} <- run_container(name, repl_set_name),
         {:ok, ips} when length(ips) > 0 <- container_ip(name) do
      {:ok, ips}
    else
      {:ok, []} ->
        {:error, :docker_missing_ip}
      error -> error
    end
  end

  def reconfigure(name, repl_set_name) do
    with {:ok, ips} when length(ips) > 0 <- container_ip(name) do
      {:ok, ips}
    else
      _ ->
        try_reconfigure_with_container(name, repl_set_name)
    end
  end

  defp try_reconfigure_with_container(name, repl_set_name) do
    with {:ok, _} <- start_container(name),
         {:ok, ips} when length(ips) > 0 <- container_ip(name) do
      {:ok, ips}
    else
      {:ok, []} ->
        {:error, :docker_missing_ip}
      error ->
        try_reconfigure_without_container(error, name, repl_set_name)
    end
  end

  defp try_reconfigure_without_container(error, name, repl_set_name) do
    with {:ok, _} <- run_container(name, repl_set_name),
         {:ok, ips} when length(ips) > 0 <- container_ip(name) do
      {:ok, ips}
    else
      {:ok, []} ->
        {:error, {error, :docker_missing_ip}}
      inner_error ->
        {:error, {error, inner_error}}
    end
  end

  def docker(args) do
    opts = [stderr_to_stdout: true]

    with {value, 0} <- System.cmd("docker", args, opts) do
      {:ok, String.trim(value)}
    else
      {error, _} -> {:error, String.trim(error)}
    end
  end

  def kill(name, opts \\ []) do
    extra = case opts[:signal] do
      nil -> []
      signal -> ["-s", signal]
    end

    with {:ok, _} <- docker Enum.concat([["kill"], extra, [name]]) do
      :ok
    end
  end

  defp docker_remove(args, items) do
    if String.length(items) > 0 do
      items = String.split(items, ~r/\s/, trim: true)
      with {:ok, _} <- docker(args ++ items) do
        :ok
      end
    else
      :ok
    end
  end

  def delete(name) do
    with :ok <- docker_remove(["rm", "-v"], name),
         {:ok, images} = docker(["images", "-qf", "dangling=true"]) do
      docker_remove(["rmi"], images)
    end
  end

  def discover(name) do
    args = ["ps", "-af", "name=#{name}", "--format", "{{ .ID }}"]
    with {:ok, output} <- docker(args) do
      String.length(output) > 0
    else
      _ -> false
    end
  end

  def start_container(name) do
    docker ["start", name]
  end

  def run_container(name, repl_set_name) do
    docker [
      "run", "-d", "--name", name, "--restart", "on-failure:10", "mongo",
      "mongod", "--replSet", repl_set_name
    ]
  end

  def container_ip(container) do
    args = [
      "inspect", "-f",
      "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}",
      container
    ]

    with {:ok, ip_addresses} <- docker(args) do
      {:ok, String.split(ip_addresses, ~r/\s/, trim: true)}
    end
  end

  def wait_for_container(container_ip) do
    case :gen_tcp.connect(String.to_atom(container_ip), 27017, []) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        :ok
      {:error, :econnrefused} ->
        Process.sleep(100)
        wait_for_container(container_ip)
      {:error, _} = error ->
        error
    end
  end

  defp replica_set_to_host(%Mongoman.ReplicaSetConfig{id: repl_set_name,
                                                      members: members}) do
    hosts =
      members
      |> Enum.map(fn %Mongoman.ReplicaSetMember{host: host} -> host end)
      |> Enum.join(",")
    "#{repl_set_name}/#{hosts}"
  end

  defp mongo_opts([{:replica_set, replica_set_config} | rest]),
    do: ["--host", replica_set_to_host(replica_set_config) | mongo_opts(rest)]
  defp mongo_opts([{:host, host} | rest]),
    do: ["--host", to_string(host) | mongo_opts(rest)]
  defp mongo_opts([{:database, db} | rest]), do: [db | mongo_opts(rest)]
  defp mongo_opts([_ | rest]), do: mongo_opts(rest)
  defp mongo_opts([]), do: ["--quiet"]

  defp validate_opts(opts) do
    if Keyword.has_key?(opts, :replica_set) && Keyword.has_key?(opts, :host) do
      {:error, :badarg}
    else
      {:ok, mongo_opts(opts)}
    end
  end

  def mongo(js, opts \\ []) do
    run_js = "JSON.stringify(#{to_string js})"
    with {:ok, args} <- validate_opts(opts),
         args = ["--eval", run_js | args],
         {output, 0} <- System.cmd("mongo", args) do
      Poison.decode(String.trim(output))
    else
      {error, _} -> {:error, String.trim(error)}
    end
  end
end
