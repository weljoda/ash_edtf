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
      aliases: aliases(),
      description: @description,
      package: package(),
      docs: docs(),
      source_url: @source_url
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"]
    ]
  end

  defp aliases do
    [
      test: ["ash.setup --quiet", "test"]
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
      {:ash, "~> 3.32"},
      {:edtf, "~> 2.0"},
      # Optional integrations: compiled in only when the consuming app has them.
      {:ash_postgres, "~> 2.13", optional: true},
      {:phoenix_live_view, "~> 1.0", optional: true},
      {:phoenix_html, "~> 4.0", optional: true},
      {:jason, "~> 1.4", optional: true},
      # For the upcoming `mix igniter.install ash_edtf` installer
      {:igniter, "~> 0.6", optional: true},
      # Dev / test
      {:lazy_html, ">= 0.1.0", only: :test},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
