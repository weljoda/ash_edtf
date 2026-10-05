defmodule AshEdtf.Expressions.Month do
  @moduledoc "`edtf_month(day)` — see `AshEdtf.Expressions.DayPart`."
  use AshEdtf.Expressions.DayPart, name: :edtf_month, part: :month
end
