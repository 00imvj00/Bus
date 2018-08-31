defmodule Bus.Mixfile do
  use Mix.Project

  def project do
    [
      app: :bus,
      version: "0.2.0",
      elixir: "~> 1.7",
      description: description(),
      package: package(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger], mod: {Bus, []}]
  end

  defp deps do
    [{:ex_doc, "~> 0.12", only: :dev}]
  end

  defp description do
    """
      Bus is Mqtt client written in elixir. It aims to be dafecto mqtt client for elixir.
    """
  end

  defp package do
    [
      name: :bus,
      files: ["lib", "mix.exs", "README.md", "LICENSE*"],
      maintainers: ["00imvj00"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/00imvj00/Bus", "Docs" => ""}
    ]
  end
end
