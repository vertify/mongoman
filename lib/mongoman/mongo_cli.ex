defmodule Mongoman.MongoCLI do
  @moduledoc false

  def mongod(name, repl_set_name, version) do
    with {:ok, _} <- run_container(name, repl_set_name, version),
         {:ok, host} <- container_host(name) do
      {:ok, host}
    else
      {:ok, []} ->
        {:error, :docker_missing_ip}
      error -> error
    end
  end

  def reconfigure(name, repl_set_name) do
    with {:ok, host} <- container_host(name) do
      {:ok, host}
    else
      _ ->
        try_reconfigure_with_container(name, repl_set_name)
    end
  end

  defp try_reconfigure_with_container(name, repl_set_name) do
    with {:ok, _} <- start_container(name),
         {:ok, host} <- container_host(name) do
      {:ok, host}
    else
      {:ok, []} ->
        {:error, :docker_missing_ip}
      error ->
        try_reconfigure_without_container(error, name, repl_set_name)
    end
  end

  defp try_reconfigure_without_container(error, name, repl_set_name) do
    with {:ok, _} <- run_container(name, repl_set_name, "latest"),
         {:ok, host} <- container_host(name) do
      {:ok, host}
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

  def run_container(name, repl_set_name, version) do
    docker [
      "run", "-d", "-P", "--name", name, "--restart", "on-failure:10",
      "mongo:#{version}", "mongod", "--replSet", repl_set_name
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

  def container_port(container) do
    args = [
      "inspect", "-f",
      "{{(index (index .NetworkSettings.Ports \"27017/tcp\") 0).HostPort}}",
      container
    ]

    with {:ok, port_str} <- docker(args),
         {port, _} <- Integer.parse(port_str) do
      {:ok, port}
    else
      :error ->
        {:error, :port_not_integer}
      error -> error
    end
  end

  def container_host(container, port \\ 27017) do
    with {:ok, [ip | _]} <- container_ip(container) do
      {:ok, "#{ip}:#{to_string port}"}
    else
      {:ok, []} ->
        {:error, :docker_missing_ip}
      error -> error
    end
  end

  def host_to_port(host) do
    %{port: port} = URI.parse("mongodb://" <> host)
    port
  end

  def wait_for_container(name) do
    case mongo(name, "db.version()", no_json: true) do
      {:ok, _} ->
        :ok
      {:error, _} ->
        Process.sleep(100)
        wait_for_container(name)
    end
  end

  defp replica_set_to_host(%Mongoman.ReplicaSetConfig{id: repl_set_name, members: members}) do
    hosts =
      members
      |> Enum.map(fn %Mongoman.ReplicaSetMember{host: host} -> host end)
      |> Enum.join(",")
    "#{repl_set_name}/#{hosts}"
  end

  defp mongo_opts([{:replica_set, replica_set_config} | rest]),
    do: ["--host", replica_set_to_host(replica_set_config) | mongo_opts(rest)]
  defp mongo_opts([{:database, db} | rest]), do: [db | mongo_opts(rest)]
  defp mongo_opts([_ | rest]), do: mongo_opts(rest)
  defp mongo_opts([]), do: ["--quiet"]

  def mongo(name, js, opts \\ []) do
    run_js = if opts[:no_json] do
      js
    else
      "JSON.stringify(#{js})"
    end

    with {:ok, output} <- docker ["exec", name, "mongo", "--eval", run_js | mongo_opts(opts)] do
      if opts[:no_json] do
        {:ok, output}
      else
        Poison.decode(output)
      end
    end
  end
end
