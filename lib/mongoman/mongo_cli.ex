defmodule Mongoman.MongoCLI do
  def mongod(name, repl_set_name) do
    with {:ok, _} <- create_container(name, repl_set_name),
         {:ok, ips} when length(ips) > 0 <- container_ip(name) do
      {:ok, ips}
    else
      {:ok, []} ->
        {:error, :docker_missing_ip}
      error -> error
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

  def kill(name) do
    with {:ok, _} <- docker ["kill", name] do
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

  defp remove_containers(containers),
    do: docker_remove(["rm", "-f"], containers)
  defp remove_images(images),
    do: docker_remove(["rmi", "-f"], images)
  defp remove_volumes(volumes),
    do: docker_remove(["volume", "rm"], volumes)

  def clear_docker do
    with {:ok, containers} = docker(["ps", "-aq"]),
         {:ok, images} = docker(["images", "-q"]),
         {:ok, volumes} = docker(["volume", "ls", "-q"]),
         :ok <- remove_containers(containers),
         :ok <- remove_images(images),
         :ok <- remove_volumes(volumes) do
      :ok
    end
  end

  def create_container(name, repl_set_name) do
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

  def mongo(js, host) do
    args = ["--eval", to_string(js), "--quiet", "--host", to_string(host)]
    with {output, 0} <- System.cmd("mongo", args) do
      {:ok, String.trim(output)}
    else
      {error, _} -> {:error, String.trim(error)}
    end
  end
end
