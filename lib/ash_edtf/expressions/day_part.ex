defmodule AshEdtf.Expressions.DayPart do
  @moduledoc """
  Shared implementation of the calendar-part expressions on `AshEdtf.Day`
  values: `edtf_year/1`, `edtf_month/1` and `edtf_decade/1`.

  ```elixir
  calculate :first_year, :integer, expr(edtf_year(date[:lower]))
  ```

  In Postgres they call `edtf_day_year` / `edtf_day_month` /
  `edtf_day_decade`, which work for any year (unlike `extract`). Years are
  astronomical (0 = 1 BC); a decade is its first year (1850 for 1850–1859).
  """

  defmacro __using__(opts) do
    name = Keyword.fetch!(opts, :name)
    part = Keyword.fetch!(opts, :part)
    sql = "edtf_day_#{part}(?)"

    quote do
      use Ash.CustomExpression, name: unquote(name), arguments: [[AshEdtf.Day]]

      def expression(AshPostgres.DataLayer, [day]) do
        {:ok, expr(type(fragment(unquote(sql), ^day), :integer))}
      end

      def expression(data_layer, [day]) when data_layer in [Ash.DataLayer.Ets, Ash.DataLayer.Simple] do
        {:ok, expr(type(fragment(&__MODULE__.part_of/1, ^day), :integer))}
      end

      @doc "Elixir evaluation for Ets / Simple data layers."
      def part_of(day), do: AshEdtf.Expressions.DayPart.unquote(part)(day)

      def expression(_data_layer, _args), do: :unknown
    end
  end

  @doc "Astronomical year of a day (0 = 1 BC), or `nil`."
  def year(%Date{year: year}), do: year
  def year(_day), do: nil

  @doc "Month (1–12) of a day, or `nil`."
  def month(%Date{month: month}), do: month
  def month(_day), do: nil

  @doc "First year of a day's decade (1850 for 1850–1859, -1850 for -1850 to -1841), or `nil`."
  def decade(%Date{year: year}), do: Integer.floor_div(year, 10) * 10
  def decade(_day), do: nil
end
