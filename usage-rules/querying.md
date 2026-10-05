# Querying EDTF values

Bounds are `AshEdtf.Day` values: `Date`s in Elixir, `bigint` day numbers in
Postgres. Inside Ash expressions this is mostly invisible; it matters where a
bound meets SQL date handling.

## Members

| Member | Type | Meaning |
|---|---|---|
| `date[:value]` | `:string` | the EDTF string — display only, never for date logic |
| `date[:lower]`, `date[:upper]` | `AshEdtf.Day` | first / last day covered; `nil` when that side isn't `:closed` |
| `date[:lower_bound]`, `date[:upper_bound]` | `AshEdtf.Bound` | `:closed`, `:open`, `:unknown` |

## Period search

```elixir
# overlaps 1850–1859 (open and unknown sides count as unbounded)
filter expr(edtf_overlaps(date, ^~D[1850-01-01], ^~D[1859-12-31]))

# everything up to 1700 (nil = open side of the period)
filter expr(edtf_overlaps(date, nil, ^~D[1700-12-31]))

# strict: only dates known to end before 1700
filter expr(date[:upper_bound] == :closed and date[:upper] < ^~D[1700-01-01])
```

Prefer `edtf_overlaps/3` over hand-written `date[:lower] <= ^to and
date[:upper] >= ^from`: the hand-written form silently drops open/unknown
sides, and only `edtf_overlaps/3` can use the optional GiST index (see
`ash_edtf:postgres`).

## Comparing with other dates

```elixir
# another :date attribute, calculation or today()
filter expr(date[:upper] <= edtf_day(published_on))
filter expr(date[:lower] > edtf_day(today()))

# literal Date params work directly
filter expr(date[:lower] >= ^~D[1850-01-01])
```

Without `edtf_day/1`, comparing a bound with a `date` expression fails with
`cannot cast type date to bigint`. Convert the date side, not the bound, so
indexes on the bound stay usable.

## Calendar parts and grouping

```elixir
calculate :year, :integer, expr(edtf_year(date[:lower]))
calculate :month, :integer, expr(edtf_month(date[:lower]))
calculate :decade, :integer, expr(edtf_decade(date[:lower]))   # 1850 for 1850–1859
```

Years are astronomical (0 = 1 BC, -1845 = 1846 BC), as in Elixir. A decade is
its first year (`-1850` for -1850 to -1841).

## Calculations and aggregates

Declare anything that returns a bound as `AshEdtf.Day`:

```elixir
calculate :earliest_date, AshEdtf.Day,
  expr(min(dates, expr: date[:lower], expr_type: AshEdtf.Day))
```

Declaring `:date` instead fails when the query runs, with
`cannot cast type bigint to date` (the bound is a day number in Postgres).
The aggregate DSL (`min :x, :dates, :field`) only takes attribute names, so
aggregate a bound with an inline `min(..., expr: ...)` calculation as above.

## Sorting and identities

- Sort with `Ash.Sort.expr_sort(date[:lower], AshEdtf.Day)` (requires
  `require Ash.Sort`), or by a calculation returning `date[:lower]`. Sorting
  by the attribute, or with `sort(date: [:lower])`, orders by the EDTF string.
- Identities and upserts may include an `AshEdtf.Type` attribute, e.g.
  `identity :unique_date, [:event_id, :date]`; equality is by EDTF string.
