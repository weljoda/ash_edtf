# AshEdtf

[EDTF](https://www.loc.gov/standards/datetime/) (Extended Date/Time Format, ISO 8601-2) dates for
[Ash](https://ash-hq.org), stored together with the date range they cover.

Historical and archival dates are often uncertain (`1850?`), approximate (`1850~`), partial
(`185X`), ranges (`1850/1860`) or open-ended (`../1850`). EDTF can express all of them, but a string
can't be filtered or sorted. `AshEdtf.Type` parses the string on cast and stores it with its derived
lower and upper bound in one Postgres composite column, so the two can never drift apart:

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

- **Lossless bounds.** Bounds are `Date`s in Elixir and day numbers in Postgres, so any EDTF year
  works, including `Y-170000000`; there is no 4713 BC limit.
- **Open vs. unknown.** Each side records whether it is `:closed`, `:open` (`1850/..`) or
  `:unknown` (`1850/`).
- **Typed queries** on the bounds: `date[:lower] >= ^~D[1850-01-01]`, sorting, aggregates.
- **Period search** with `edtf_overlaps(date, ^from, ^to)`, optionally backed by a GiST index.
- **Calendar parts** for any year: `edtf_year/1`, `edtf_month/1`, `edtf_decade/1`, and
  `edtf_day/1` to compare bounds with ordinary date columns.
- **Form helpers** for Phoenix: `AshEdtf.Phoenix.humanize_field/1` and a headless `<.edtf_input>`.

## Installation

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

Register the Ash expressions (compile-time config of `ash`):

```elixir
config :ash, :custom_expressions, [
  AshEdtf.Expressions.Overlaps,
  AshEdtf.Expressions.Day,
  AshEdtf.Expressions.Year,
  AshEdtf.Expressions.Month,
  AshEdtf.Expressions.Decade
]
```

After changing that list, recompile Ash with `mix deps.compile ash --force`.

## Usage

```elixir
attributes do
  attribute :date, AshEdtf.Type, allow_nil?: false, public?: true
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

Query the bounds, never the EDTF string. See `AshEdtf.Type` ("Working with bounds", "Indexing")
for the details, including raw-SQL helpers like `edtf_day_year(bigint)`.

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

MIT, see [LICENSE](LICENSE).
