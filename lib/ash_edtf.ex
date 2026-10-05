defmodule AshEdtf do
  @moduledoc """
  EDTF (Extended Date/Time Format, ISO 8601-2) dates for Ash.

  An `AshEdtf.Type` attribute stores the EDTF string together with the date
  range it covers, derived on cast with the `edtf` library:

  ```elixir
  attribute :date, AshEdtf.Type
  ```

  ```elixir
  record.date
  #=> %AshEdtf.Value{value: "../1850-06", lower: nil, upper: ~D[1850-06-30],
  #     lower_bound: :open, upper_bound: :closed}
  ```

  Query the bounds, never the string:

  ```elixir
  filter expr(date[:lower] >= ^~D[1850-01-01])
  filter expr(edtf_overlaps(date, ^from, ^to))
  calculate :decade, :integer, expr(edtf_decade(date[:lower]))
  ```

  ## Modules

  - `AshEdtf.Type` — the attribute type; storage, bounds, indexing and
    "Working with bounds".
  - `AshEdtf.Value` — the cast value.
  - `AshEdtf.Day` — a bound: a `Date` in Elixir, a day number in Postgres
    (any year).
  - `AshEdtf.AshPostgresExtension` — the Postgres type and SQL helpers.
  - `AshEdtf.Expressions.Overlaps`, `AshEdtf.Expressions.Day`,
    `AshEdtf.Expressions.Year`, `AshEdtf.Expressions.Month`,
    `AshEdtf.Expressions.Decade` — Ash expressions.
  - `AshEdtf.Phoenix` — form helpers (optional, needs `phoenix_live_view`).
  """
end
