import Config

# `custom_expressions` is compile-time config of `ash`; the test resources use
# all of them.
config :ash, :custom_expressions, [
  AshEdtf.Expressions.Overlaps,
  AshEdtf.Expressions.Day,
  AshEdtf.Expressions.Year,
  AshEdtf.Expressions.Month,
  AshEdtf.Expressions.Decade
]

if Mix.env() == :test do
  config :ash_edtf,
    ecto_repos: [AshEdtf.Test.Repo],
    ash_domains: [AshEdtf.Test.Domain]

  config :ash_edtf, AshEdtf.Test.Repo,
    username: System.get_env("TEST_DB_USER", "postgres"),
    password: System.get_env("TEST_DB_PASS", "postgres"),
    hostname: System.get_env("TEST_DB_HOST", "localhost"),
    port: String.to_integer(System.get_env("TEST_DB_PORT", "5432")),
    database: System.get_env("TEST_DB_NAME", "ash_edtf_test"),
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 10

  config :ash, default_string_length_count: :codepoints
  config :ash, :validate_domain_resource_inclusion?, false
  config :ash, :validate_domain_config_inclusion?, false
  config :logger, level: :warning
end
