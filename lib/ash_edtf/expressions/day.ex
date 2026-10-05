defmodule AshEdtf.Expressions.Day do
  @moduledoc """
  `edtf_day(date)` — converts a `:date` expression (an attribute, a
  calculation, `today()`) into an `AshEdtf.Day`, so EDTF bounds can be
  compared with ordinary date columns:

  ```elixir
  filter expr(date[:lower] <= edtf_day(published_on))
  ```

  Bounds are day numbers in Postgres, so comparing them with a `date`
  directly is a type error; converting the date side keeps the bound usable
  by indexes. For literal values this isn't needed: `date[:lower] <= ^date`
  already works.
  """
  use Ash.CustomExpression, name: :edtf_day, arguments: [[:date]]

  def expression(AshPostgres.DataLayer, [date]) do
    {:ok, expr(type(fragment("edtf_date_to_day(?::date)", ^date), AshEdtf.Day))}
  end

  # A bound is already a `Date` in Elixir.
  def expression(data_layer, [date]) when data_layer in [Ash.DataLayer.Ets, Ash.DataLayer.Simple] do
    {:ok, expr(type(^date, AshEdtf.Day))}
  end

  def expression(_data_layer, _args), do: :unknown
end
