[![Elixir CI](https://github.com/weljoda/ash_edtf/actions/workflows/elixir.yml/badge.svg)](https://github.com/weljoda/ash_edtf/actions/workflows/elixir.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Hex version badge](https://img.shields.io/hexpm/v/ash_edtf.svg)](https://hex.pm/packages/ash_edtf)
[![Hexdocs badge](https://img.shields.io/badge/docs-hexdocs-purple)](https://hexdocs.pm/ash_edtf)
[![REUSE status](https://api.reuse.software/badge/github.com/weljoda/ash_edtf)](https://api.reuse.software/info/github.com/weljoda/ash_edtf)

# AshEdtf

[EDTF](https://www.loc.gov/standards/datetime/) (Extended Date/Time Format, ISO 8601-2) dates for
[Ash](https://ash-hq.org), stored together with the date range they cover.

Historical and archival dates are often uncertain (`1850?`), approximate (`1850~`), partial
(`185X`), ranges (`1850/1860`) or open-ended (`../1850`). EDTF can express all of them, but a string
can't be filtered or sorted. `AshEdtf.Type` parses the string on cast and stores it with its derived
lower and upper bound in one Postgres composite column:

```elixir
attribute :date, AshEdtf.Type
```

```elixir
record.date
#=> %AshEdtf.Value{
#     value: "../1850-06",
#     lower: nil,            lower_bound: :open,
#     upper: ~D[1850-06-30], upper_bound: :closed
#   }
```

## Features

- **Any year.** Bounds are `Date`s in Elixir and day numbers in Postgres, so every EDTF year
  works, including BCE and long years like `Y-170000000`.
- **Open vs. unknown.** Each side records whether it is `:closed`, `:open` (`1850/..`) or
  `:unknown` (`1850/`).
- **Typed queries** on the bounds: `date[:lower] >= ^~D[1850-01-01]`, sorting, aggregates.
- **Period search** with `edtf_overlaps(date, ^from, ^to)`, optionally backed by a GiST index.
- **Calendar parts** for any year: `edtf_year/1`, `edtf_month/1`, `edtf_decade/1`, and
  `edtf_day/1` to compare bounds with ordinary date columns.
- **Form helpers** for Phoenix: `AshEdtf.Phoenix.humanize_field/1` and a headless `<.edtf_input>`
  with an optional label and help listing common EDTF patterns.

## Installation

With [Igniter](https://hexdocs.pm/igniter):

```sh
mix igniter.install ash_edtf
```

The installer registers the `:edtf` type short name and the Ash expressions, recompiles `ash` (both
settings are compile-time config), and, if you use AshPostgres, adds the Postgres extension to your
repos and generates its migration. If you add AshPostgres later, run
`mix ash_edtf.add_to_ash_postgres`. For your test build, run `MIX_ENV=test mix deps.compile ash --force`
once.

### Manual installation

```elixir
def deps do
  [
    {:ash_edtf, "~> 0.1.0"}
  ]
end
```

Add the Postgres extension to your repo and generate migrations:

```elixir
defmodule MyApp.Repo do
  use AshPostgres.Repo, otp_app: :my_app

  def installed_extensions do
    ["ash-functions", AshEdtf.AshPostgresExtension]
  end
end
```

```sh
mix ash.codegen add_ash_edtf
```

Register the type short name and the Ash expressions:

```elixir
config :ash,
  custom_types: [edtf: AshEdtf.Type],
  custom_expressions: [
    AshEdtf.Expressions.Overlaps,
    AshEdtf.Expressions.Day,
    AshEdtf.Expressions.Year,
    AshEdtf.Expressions.Month,
    AshEdtf.Expressions.Decade
  ]
```

Both are compile-time config of `ash`, so recompile it afterwards with `mix deps.compile ash --force`.

## Usage

```elixir
attributes do
  attribute :date, :edtf, allow_nil?: false, public?: true
end

calculations do
  calculate :decade, :integer, expr(edtf_decade(date[:lower]))
end
```

```elixir
# dates that can fall into the 1850s (open and unknown sides count as unbounded)
Ash.Query.filter(MyApp.Event, edtf_overlaps(date, ^~D[1850-01-01], ^~D[1859-12-31]))

# only dates whose end is known
Ash.Query.filter(MyApp.Event, date[:upper_bound] != :unknown)

# earliest date of a parent record
calculate :earliest, AshEdtf.Day, expr(min(events, expr: date[:lower], expr_type: AshEdtf.Day))
```

Query the bounds, never the EDTF string.

## Guides

- [Getting started](documentation/tutorials/getting-started-with-ash-edtf.md)
- [EDTF values](documentation/topics/edtf-values.md) — what each input stores
- [Querying](documentation/topics/querying.md) — period search, comparisons, sorting, calendar parts
- [Postgres](documentation/topics/postgres.md) — installed objects, indexing, raw SQL
- [Forms](documentation/topics/forms.md)

## Data layers

AshPostgres is the only supported persistent data layer. ETS and `Ash.DataLayer.Simple` work and
evaluate the expressions in Elixir. Data layers without composite types (e.g. AshSqlite) are not
supported.

## Development

Tests need a local Postgres (defaults: `postgres`/`postgres` on `localhost:5432`, override with
`TEST_DB_*` environment variables):

```sh
mix test
```

## License

MIT, see [LICENSES/MIT.txt](LICENSES/MIT.txt).
