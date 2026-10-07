defmodule AshBackpex.MixProject do
  use Mix.Project

  @version "0.3.4"
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
      docs: &docs/0,
      aliases: aliases()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "guides/getting-started.md",
        "guides/upgrading-to-0.3.md",
        "guides/inline-crud.md"
      ],
      groups_for_extras: [
        Guides: ~r/guides\/.*/
      ],
      groups_for_modules: [
        "LiveResource DSL": [
          AshBackpex.LiveResource,
          AshBackpex.LiveResource.Dsl,
          AshBackpex.LiveResource.Dsl.Field,
          AshBackpex.LiveResource.Dsl.Filter,
          AshBackpex.LiveResource.Dsl.ItemAction,
          AshBackpex.LiveResource.Info
        ],
        Adapter: [
          AshBackpex.Adapter
        ],
        Internals: [
          AshBackpex.BasicSearch,
          AshBackpex.Fields.BelongsTo,
          AshBackpex.Fields.Embedded,
          AshBackpex.Fields.InlineCRUD,
          AshBackpex.LoadSelectResolver,
          AshBackpex.LiveResource.Transformers.GenerateBackpex
        ]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ash, "~> 3.0"},
      {:ash_phoenix, "~> 2.3.14"},
      {:backpex, "~> 0.22.0"},
      {:spark, "~> 2.0"},
      {:phoenix_html, "~> 3.0 or ~> 4.0"},

      # Dev/Test dependencies
      {:faker, "~> 0.19.0", only: :test},
      {:lazy_html, "~> 0.1", only: :test},
      {:simple_sat, "~> 0.1.3", only: [:dev, :test]},
      {:ash_sqlite, "~> 0.1", only: :test},
      {:ex_doc, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:usage_rules, "~> 0.1", only: :dev, runtime: false},
      {:ex_check, "~> 0.14", only: [:dev, :test]},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.15.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      name: "ash_backpex",
      files: ~w(lib guides mix.exs README.md CHANGELOG.md LICENSE usage-rules.md),
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

  def cli do
    [
      preferred_envs: [
        ci: :test,
        "test.adapter": :test,
        "test.dsl": :test,
        "test.fields": :test,
        "test.filters": :test,
        "test.forms": :test,
        "test.harness": :test
      ]
    ]
  end

  defp aliases do
    [
      credo: "credo --strict",
      "test.adapter": "test test/ash_backpex/adapter_test.exs",
      "test.dsl": "test test/ash_backpex/live_resource",
      "test.fields":
        "test test/ash_backpex/fields test/ash_backpex/relationship_options_test.exs",
      "test.filters": "test test/ash_backpex/filters",
      "test.forms": "test test/ash_backpex/ash_changeset_to_phoenix_form_test.exs",
      "test.harness": "test test/harness",
      "demo.check": [
        "cmd --cd demo env MIX_ENV=dev mix deps.get --check-locked",
        "cmd --cd demo env MIX_ENV=dev mix compile --warnings-as-errors"
      ],
      ci: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo --strict",
        "sobelow --exit",
        "docs --warnings-as-errors",
        "test",
        "demo.check"
      ]
    ]
  end
end
