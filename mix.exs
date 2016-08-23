defmodule Mongoman.Mixfile do
  use Mix.Project

  def project do
    [app: :mongoman,
     description: "Configures and starts local or distributed MongoDB clusters",
     version: "0.1.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     docs: fn ->
       {ref, 0} =
         System.cmd("git", ["rev-parse", "--verify", "--quiet", "HEAD"])
       [source_ref: ref, main: "readme", extras: ["README.md"]]
     end,
     package: package()]
  end

  def application do
    [applications: [:logger, :erlexec]]
  end

  defp deps do
    [{:erlexec, "~> 1.2.2"},
     {:credo, "~> 0.4.8", only: [:dev, :test]},
     {:ex_doc, "~> 0.13.0", only: :dev}]
  end

  defp package do
    [maintainers: ["Vertify", "Christian Howe"],
     licenses: ["Apache 2.0"],
     links: %{"Docs" => "https://hexdocs.pm/mongoman",
              "GitHub" => "https://github.com/vertify/mongoman"}]
  end
end
