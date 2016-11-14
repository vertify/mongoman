defmodule Mongoman.Mongod do
  def start(name, repl_set_name) do
    with {:ok, _} <- create_container(name, repl_set_name),
         {:ok, ips} when length(ips) > 0 <- container_ip(name),
         ip = List.first(ips) do
      {:ok, ips}
    else
      {:ok, []} -> {:error, :docker_missing_ip}
      error -> error
    end
  end

  def create_container(name, repl_set_name) do
    args = [
      "run", "-d", "--name", name, "mongo",
      "mongod", "--replSet", repl_set_name
    ]
    opts = [stderr_to_stdout: true]

    with {container_id, 0} <- System.cmd("docker", args, opts) do
      {:ok, String.trim(container_id)}
    else
      {error, _} -> {:error, String.trim(error)}
    end
  end

  def container_ip(container) do
    args = [
      "inspect", "-f",
      "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}",
      container
    ]
    opts = [stderr_to_stdout: true]

    with {ip_addresses, 0} <- System.cmd("docker", args, opts) do
      {:ok, String.split(ip_addresses, ~r{\s}, trim: true)}
    else
      {error, _} -> {:error, String.trim(error)}
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
end
