defmodule AshBackpex.MixProject do
  use Mix.Project

  @version "0.0.3"
  @source_url "https://github.com/enoonan/ash_backpex"

  def project do
    [
      app: :ash_backpex,
      name: "Ash Backpex",
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      package: package(),
      description: description(),
      source_url: @source_url,
      docs: &docs/0
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp docs do
    [
      # The main page in the docs
      main: "readme",
      extras: ["README.md"]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:ash, "~> 3.0"},
      {:backpex, "~> 0.8"},
      {:spark, "~> 2.0"},
      {:phoenix_html, "~> 3.0 or ~> 4.0"},
      {:ash_sqlite, "~> 0.1", only: :test}
    ]
  end

  defp package do
    [
      name: "ash_backpex",
      files: ~w(lib mix.exs README.md LICENSE),
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Ash Framework" => "https://ash-hq.org/",
        "Backpex" => "https://backpex.live/"
      },
      maintainers: ["Eileen Noonan"]
    ]
  end

  defp description do
    """
    Integration library between Ash Framework and Backpex admin interface (early development).
    Provides a DSL for creating admin interfaces for Ash resources.
    """
  end
end
