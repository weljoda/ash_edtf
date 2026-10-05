# EDTF Values

An `AshEdtf.Type` attribute is set with an EDTF string. Casting trims it,
parses it with the [`edtf`](https://hexdocs.pm/edtf) library and derives the
date range it covers. The result is an `AshEdtf.Value`:

```elixir
%AshEdtf.Value{
  value: "../1850-06",       # the trimmed EDTF string
  lower: nil,                # first day covered, or nil
  upper: ~D[1850-06-30],     # last day covered, or nil
  lower_bound: :open,        # :closed | :open | :unknown
  upper_bound: :closed
}
```

`to_string/1`, HTML rendering and JSON encoding all return the EDTF string.

## Bounds

Each side of the range has a bound kind:

| Bound | Meaning | Date |
|---|---|---|
| `:closed` | the side has a concrete date | set |
| `:open` | explicitly open-ended (`..`): any date in that direction | `nil` |
| `:unknown` | the side is unknown (empty, e.g. `1850/`) | `nil` |

The date of a side is set exactly when its bound is `:closed`. Bounds are
always derived from the string; setting a struct with different bounds has no
effect.

## What is stored

| Input | Range | Bounds |
| --- | --- | --- |
| `1984-06-15` | 1984-06-15 – 1984-06-15 | closed / closed |
| `2000-02` | 2000-02-01 – 2000-02-29 | closed / closed |
| `1984` | 1984-01-01 – 1984-12-31 | closed / closed |
| `1984/1986` | 1984-01-01 – 1986-12-31 | closed / closed |
| `1984/..` | 1984-01-01 – none | closed / open |
| `../1984` | none – 1984-12-31 | open / closed |
| `1984/` | 1984-01-01 – none | closed / unknown |
| `/1984` | none – 1984-12-31 | unknown / closed |
| `198` (decade), `198X` | 1980-01-01 – 1989-12-31 | closed / closed |
| `19` (century), `19XX` | 1900-01-01 – 1999-12-31 | closed / closed |
| `[1984,1985]`, `{1984,1985}` | 1984-01-01 – 1985-12-31 | closed / closed |
| `[1984, 1986..1988]` | 1984-01-01 – 1988-12-31 | closed / closed |
| `1984?`, `1984~`, `1984%` | 1984-01-01 – 1984-12-31 | closed / closed |
| `2020-21` (spring) | 2020-03-01 – 2020-05-31 | closed / closed |
| `2020-24` (winter) | 2020-12-01 – 2021-02-28 | closed / closed |
| `-0500` | -0500-01-01 – -0500-12-31 | closed / closed |
| `Y10000`, `Y-17E7` | the whole year 10000 / -170000000 | closed / closed |
| `" 1984 "` | stored as `"1984"` | |
| `nil`, `""`, `"   "` | stored as `nil` | |

- Qualifiers (`?`, `~`, `%`) stay in the string but don't widen the range.
- Sets and lists are stored as the range from their earliest to their latest
  member.
- Years are astronomical, as in Elixir: `-0500` is 501 BC, year `0` is 1 BC.
- Years of any size work; bounds are stored as day numbers (`AshEdtf.Day`).

## What is rejected

Invalid input is a field error, "is not a valid EDTF date":

| Input | Why |
| --- | --- |
| `1999-02-30` | not a real calendar date |
| `198x`, `y10000` | EDTF uses uppercase `X` and `Y` |
| `1` | a single character is treated as a typo |
| `Y-170000000/1850` | the `edtf` parser doesn't accept long years inside intervals, sets or lists |
| `1950S2` | the `edtf` parser doesn't accept significant digits on a four-digit year |

## Setting values

Pass the string through any action that accepts the attribute:

```elixir
Ash.Changeset.for_create(Letter, :create, %{date: "1850~"})
```

In atomic updates the value must be a literal; setting it from an expression
isn't supported, because the bounds are derived in Elixir.
