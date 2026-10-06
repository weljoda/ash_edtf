defmodule AshEdtf.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/weljoda/ash_edtf"
  @description "EDTF (Extended Date/Time Format) dates for Ash, stored with their derived date range"

  def project do
    [
      app: :ash_edtf,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      consolidate_protocols: Mix.env() != :test,
      deps: deps(),
      # CI also runs the suite against the lowest supported versions, pinned in
      # mix.floor.lock (`FLOOR_DEPS=true mix test`).
      lockfile: if(System.get_env("FLOOR_DEPS"), do: "mix.floor.lock", else: "mix.lock"),
      aliases: aliases(),
      dialyzer: [plt_add_apps: [:mix, :ex_unit]],
      description: @description,
      package: package(),
      docs: docs(),
      source_url: @source_url,
      usage_rules: usage_rules()
    ]
  end

  # `mix usage_rules.sync` writes the rules of the libraries this package
  # builds on into AGENTS.md, for contributors and coding agents.
  defp usage_rules do
    [
      file: "AGENTS.md",
      usage_rules: [
        :elixir,
        :otp,
        {:ash, link: :markdown},
        {:ash_postgres, link: :markdown},
        {:igniter, link: :markdown}
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files:
        ~w(lib .formatter.exs mix.exs README.md LICENSES REUSE.toml CHANGELOG.md documentation usage-rules.md usage-rules)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extra_section: "GUIDES",
      extras: [
        {"README.md", title: "Home"},
        "documentation/tutorials/getting-started-with-ash-edtf.md",
        "documentation/topics/edtf-values.md",
        "documentation/topics/querying.md",
        "documentation/topics/postgres.md",
        "documentation/topics/forms.md",
        "CHANGELOG.md",
        {"LICENSES/MIT.txt", title: "License"}
      ],
      groups_for_extras: [
        Tutorials: ~r'documentation/tutorials',
        Topics: ~r'documentation/topics',
        "About AshEdtf": ["CHANGELOG.md", "LICENSES/MIT.txt"]
      ],
      groups_for_modules: [
        AshEdtf: [AshEdtf, AshEdtf.Type, AshEdtf.Value, AshEdtf.Day, AshEdtf.Bound],
        Expressions: ~r/^AshEdtf\.Expressions\./,
        AshPostgres: [AshEdtf.AshPostgresExtension],
        Phoenix: [AshEdtf.Phoenix]
      ]
    ]
  end

  defp aliases do
    [
      test: ["ash.setup --quiet", "test"],
      credo: "credo --strict",
      sobelow: "sobelow --skip"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ash, "~> 3.5 and >= 3.5.41"},
      {:edtf, "~> 2.0"},
      # Optional integrations: compiled in only when the consuming app has them.
      {:ash_postgres, "~> 2.5 and >= 2.5.6", optional: true},
      {:phoenix_live_view, "~> 1.0", optional: true},
      {:phoenix_html, "~> 4.0", optional: true},
      {:jason, "~> 1.4", optional: true},
      # For the upcoming `mix igniter.install ash_edtf` installer
      {:igniter, "~> 0.6", optional: true},
      # Dev / test
      {:lazy_html, ">= 0.1.0", only: :test},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:usage_rules, "~> 1.1", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:sobelow, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:mix_audit, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.17", only: [:dev, :test]},
      {:git_ops, "~> 2.12", only: [:dev, :test]}
    ]
  end
end
