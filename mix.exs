defmodule Mongoman.Mixfile do
  use Mix.Project

  def project do
    [app: :mongoman,
     version: "0.1.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     package: package()]
  end

  def application do
    [applications: [:logger, :erlexec]]
  end

  defp deps do
    [{:erlexec, "~> 1.2.2"},
     {:credo, "~> 0.4.8", only: [:dev, :test]}]
  end

  defp package do
    [name: :mongoman,
     maintainers: ["Vertify", "Christian Howe"],
     licenses: ["Apache 2.0"],
     links: %{"Docs" => "https://hexdocs.pm/mongoman",
              "GitHub" => "https://github.com/vertify/mongoman"}]
  end
end
