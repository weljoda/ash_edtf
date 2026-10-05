# Querying

Query the bounds of an EDTF value, never its string. In Elixir the bounds are
`Date`s; in Postgres they are day numbers (`AshEdtf.Day`), which keeps every
year comparable. Inside Ash expressions this is mostly invisible.

## Members

| Member | Type | Use |
|---|---|---|
| `date[:value]` | `:string` | display only |
| `date[:lower]`, `date[:upper]` | `AshEdtf.Day` | first / last day covered; `nil` unless the side is `:closed` |
| `date[:lower_bound]`, `date[:upper_bound]` | `AshEdtf.Bound` | `:closed`, `:open`, `:unknown` |

```elixir
filter expr(date[:lower] >= ^~D[1850-01-01])
filter expr(date[:upper_bound] != :unknown)
```

## Period search

`edtf_overlaps/3` is true when a value shares at least one day with an
inclusive period. Open and unknown sides count as unbounded, and `nil` leaves
that side of the period open:

```elixir
# can fall into the 1850s
filter expr(edtf_overlaps(date, ^~D[1850-01-01], ^~D[1859-12-31]))

# up to 1700
filter expr(edtf_overlaps(date, nil, ^~D[1700-12-31]))
```

A hand-written `date[:lower] <= ^to and date[:upper] >= ^from` drops every
row with an open or unknown side, and can't use the optional index (see
[Postgres](postgres.md)). For a strict search, combine a comparison with the
bound kind:

```elixir
# known to end before 1700
filter expr(date[:upper_bound] == :closed and date[:upper] < ^~D[1700-01-01])
```

## Comparing with other dates

Literal `Date` parameters work directly. To compare a bound with a date
column, calculation or `today()`, convert the date with `edtf_day/1`:

```elixir
filter expr(date[:upper] <= edtf_day(published_on))
filter expr(date[:lower] > edtf_day(today()))
```

Without it, Postgres reports `cannot cast type date to bigint`.

## Sorting

```elixir
require Ash.Sort

Ash.Query.sort(query, Ash.Sort.expr_sort(date[:lower], AshEdtf.Day))
Ash.Query.sort(query, [{Ash.Sort.expr_sort(date[:lower], AshEdtf.Day), :desc}])
```

Sorting by the attribute itself orders by the EDTF string. For sorting from
user input (tables, `sort_input`), add a calculation and sort by it:

```elixir
calculate :start_date, AshEdtf.Day, expr(date[:lower])
```

## Calendar parts

```elixir
calculate :year, :integer, expr(edtf_year(date[:lower]))
calculate :month, :integer, expr(edtf_month(date[:lower]))
calculate :decade, :integer, expr(edtf_decade(date[:lower]))
```

Years are astronomical (`0` is 1 BC). A decade is its first year: `1850` for
1850–1859, `-1850` for -1850 to -1841.

## Calculations and aggregates

Anything that returns a bound is typed `AshEdtf.Day`, which loads as a `Date`:

```elixir
calculate :earliest_date, AshEdtf.Day,
  expr(min(dates, expr: date[:lower], expr_type: AshEdtf.Day))
```

Typing it `:date` fails in Postgres with `cannot cast type bigint to date`.
Resource aggregates (`min :x, :dates, :field`) take attribute names only, so
use an inline aggregate in a calculation as above.

## Identities

An `AshEdtf.Type` attribute can be part of an identity and of upserts:

```elixir
identities do
  identity :unique_date, [:letter_id, :date]
end
```

Two values are equal when their EDTF strings are equal.

## Data layers

AshPostgres stores values in the `edtf` composite type. With `Ash.DataLayer.Ets`
and `Ash.DataLayer.Simple` the expressions above are evaluated in Elixir. Data
layers without composite types, such as AshSqlite, are not supported.
