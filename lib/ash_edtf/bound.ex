defmodule AshEdtf.Bound do
  @moduledoc """
  How one side of an EDTF date range is bounded.

  - `:closed` — the side has a concrete date.
  - `:open` — the side is explicitly open-ended (`../1850`, `1850/..`,
    `[..1850]`, `[1850..]`). Any date in that direction matches.
  - `:unknown` — the side is unknown (`/1850`, `1850/`). Some date exists,
    but it is not recorded.

  Stored as the `edtf_bound` domain (`text` restricted to these values)
  inside the `edtf` Postgres composite type.
  """
  use Ash.Type.Enum, values: [:closed, :open, :unknown]
end
