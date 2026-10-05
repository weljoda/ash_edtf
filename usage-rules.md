# AshEdtf Usage Rules

AshEdtf provides `AshEdtf.Type` (short name `:edtf` when installed) for
[EDTF](https://www.loc.gov/standards/datetime/) dates: uncertain (`1850?`),
approximate (`1850~`), partial (`185X`), ranges (`1850/1860`), open-ended
(`../1850`) and long years (`Y-170000000`). Each value carries its EDTF string
together with the date range it covers. Sub-rules: `ash_edtf:querying`,
`ash_edtf:postgres`, `ash_edtf:forms`.

## Modelling

Model each EDTF date as one `AshEdtf.Type` attribute. The bounds are part of
the value, derived on cast, so no further attributes or changes are needed.

```elixir
attribute :date_of_birth, :edtf, public?: true
```

## Values

Set the attribute with an EDTF **string**. Casting trims it, turns blank input
into `nil` and rejects invalid EDTF with "is not a valid EDTF date". Never
build an `%AshEdtf.Value{}` to set bounds yourself — they are always re-derived
from the string.

```elixir
Ash.Changeset.for_create(Event, :create, %{date: "../1850-06"})

record.date
#=> %AshEdtf.Value{value: "../1850-06", lower: nil, upper: ~D[1850-06-30],
#     lower_bound: :open, upper_bound: :closed}

to_string(record.date) #=> "../1850-06"
```

- `lower` / `upper` are `Date`s (any year, including BCE and > 9999).
- `lower_bound` / `upper_bound` are `:closed`, `:open` (`..`, explicitly
  open) or `:unknown` (empty side, e.g. `1850/`). The date is `nil` exactly
  when the bound isn't `:closed`.
- Qualifiers (`?`, `~`, `%`) stay in the string but don't widen the range.
  Sets/lists (`[1850, 1852]`) are stored as the envelope of their members.

## Querying — the essentials

Query the bounds, **never the EDTF string**.

```elixir
filter expr(date[:lower] >= ^~D[1850-01-01])
filter expr(edtf_overlaps(date, ^from, ^to))     # period search; nil from/to = open
filter expr(date[:upper_bound] != :unknown)      # exclude unknown ends
sort expr(date[:lower])                          # not `sort :date`
```

- A plain comparison drops rows whose side is `nil` (open/unknown). For "does
  this date fall into a period" use `edtf_overlaps/3`, which treats open and
  unknown sides as unbounded.
- Compare a bound with another date **column** through `edtf_day/1`:
  `date[:lower] <= edtf_day(published_on)`. Literal `Date` params need no
  wrapper.
- Calculations and aggregates over a bound are typed `AshEdtf.Day`, not
  `:date`:

```elixir
calculate :earliest, AshEdtf.Day, expr(min(dates, expr: date[:lower], expr_type: AshEdtf.Day))
calculate :decade, :integer, expr(edtf_decade(date[:lower]))
```

- Use `edtf_year/1`, `edtf_month/1`, `edtf_decade/1` for calendar parts —
  never `fragment("extract(...)")` on a bound (bounds are `bigint` day
  numbers in Postgres; mixing them with SQL dates is a type error).

See `ash_edtf:querying` for more.

## Setup

- Install with `mix igniter.install ash_edtf`. It registers `:edtf`, adds the
  expressions to `config :ash, :custom_expressions` and, with AshPostgres,
  adds `AshEdtf.AshPostgresExtension` to the repo and generates its migration.
- `custom_types` and `custom_expressions` are **compile-time** config of
  `ash`. After changing them, run `mix deps.compile ash --force` (and again
  with `MIX_ENV=test`), or compilation fails with a compile-env mismatch.
- AshPostgres is the only supported persistent data layer; ETS works.
  Data layers without composite types (e.g. AshSqlite) are not supported.

## Known limits

- Setting the attribute from an expression in an atomic update is not
  supported (bounds are derived in Elixir); pass a literal string or use
  `require_atomic? false`.
