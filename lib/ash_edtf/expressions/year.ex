defmodule AshEdtf.Expressions.Year do
  @moduledoc "`edtf_year(day)` — see `AshEdtf.Expressions.DayPart`."
  use AshEdtf.Expressions.DayPart, name: :edtf_year, part: :year
end
