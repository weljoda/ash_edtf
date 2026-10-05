# Postgres

`AshEdtf.AshPostgresExtension` installs the Postgres objects the type is
stored in. Add it to your repo (`mix igniter.install ash_edtf` or
`mix ash_edtf.add_to_ash_postgres` do this for you) and generate the
migration:

```elixir
def installed_extensions do
  ["ash-functions", AshEdtf.AshPostgresExtension]
end
```

```sh
mix ash.codegen install_ash_edtf
```

Columns of `AshEdtf.Type` attributes are then generated as `:edtf` by
`mix ash.codegen`.

## Installed objects

| Object | Description |
|---|---|
| `edtf_bound` | `text` domain: `closed`, `open`, `unknown` |
| `edtf` | composite `(value text, lower bigint, upper bigint, lower_bound edtf_bound, upper_bound edtf_bound)` |
| `edtf_range(edtf)` | the covered `int8range`, inclusive; open and unknown sides are unbounded, `NULL` gives `NULL` |
| `edtf_date_to_day(date)` | a `date` as day number |
| `edtf_day_to_date(bigint)` | a day number as `date`; errors outside the Postgres `date` range (4713 BC – 5874897 AD) |
| `edtf_day_year(bigint)` | year, any range (astronomical: `0` is 1 BC) |
| `edtf_day_month(bigint)` | month, 1–12 |
| `edtf_day_decade(bigint)` | first year of the decade |
| `edtf_day_parts(bigint)` | `(year, month, day_of_month)` |

Bounds are day numbers as in `Date.to_gregorian_days/1` (day 0 is
0000-01-01, proleptic Gregorian, like Postgres `date`).

## Indexing

Period searches with `edtf_overlaps/3` compile to
`edtf_range(col) && int8range(from, to, '[]')`, so a GiST expression index
speeds them up:

```elixir
postgres do
  custom_indexes do
    index ["edtf_range(date)"], using: "GIST"
  end
end
```

Add it only when a table is large enough for period searches to need it. The
planner uses it only for queries containing the same expression, which
`edtf_overlaps/3` guarantees.

## Raw SQL

```sql
SELECT (date).value,
       edtf_day_year((date).lower)   AS first_year,
       edtf_day_to_date((date).upper) AS last_day
FROM letters
WHERE edtf_range(date) && int8range(edtf_date_to_day('1850-01-01'), edtf_date_to_day('1859-12-31'), '[]');
```

Use the `edtf_day_*` functions instead of `extract(...)` or date arithmetic on
`(col).lower` / `(col).upper`; those are day numbers, not dates.
