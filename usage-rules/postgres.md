# AshEdtf with AshPostgres

## Setup

`AshEdtf.AshPostgresExtension` must be in the repo's `installed_extensions/0`
(the installer adds it; otherwise `mix ash_edtf.add_to_ash_postgres`). Then
generate the migration with `mix ash.codegen`. It installs:

- `edtf_bound` — `text` domain (`closed` / `open` / `unknown`)
- `edtf` — composite `(value text, lower bigint, upper bigint, lower_bound edtf_bound, upper_bound edtf_bound)`
- `edtf_range(edtf)` — the covered `int8range` (inclusive; open/unknown sides unbounded)
- `edtf_date_to_day(date)`, `edtf_day_to_date(bigint)`
- `edtf_day_year(bigint)`, `edtf_day_month(bigint)`, `edtf_day_decade(bigint)`, `edtf_day_parts(bigint)`

Columns are generated as type `:edtf` by `mix ash.codegen`; don't write them
by hand.

## Indexing

Add a GiST index only when period searches on a large table need it:

```elixir
postgres do
  custom_indexes do
    index ["edtf_range(date)"], using: "GIST"
  end
end
```

The planner only uses it for `edtf_overlaps/3`, which renders exactly
`edtf_range(col) && int8range(...)`. Hand-written range fragments won't match.

## Raw SQL

Bounds are day numbers (`Date.to_gregorian_days/1`, day 0 = 0000-01-01):

```sql
SELECT edtf_day_year((date).lower), edtf_day_to_date((date).upper) FROM events;
```

- `edtf_day_to_date/1` errors outside the Postgres `date` range
  (4713 BC – 5874897 AD); the `edtf_day_*` part functions work for any year.
- Never use `extract(...)`, `date_trunc(...)` or date arithmetic on
  `(col).lower` / `(col).upper` directly.
