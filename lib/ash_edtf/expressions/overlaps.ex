defmodule AshEdtf.Expressions.Overlaps do
  @moduledoc """
  `edtf_overlaps(edtf, from, to)` — true when an EDTF value's range shares at
  least one day with the inclusive period `from..to`.

  `open` and `unknown` sides are treated as unbounded ("don't exclude what we
  don't know"), and a `nil` `from`/`to` leaves that side of the period open.
  Filter on `edtf[:lower_bound]` / `edtf[:upper_bound]` for stricter rules.

  ```elixir
  filter expr(edtf_overlaps(date, ^from, ^to))
  ```

  In Postgres this renders as `edtf_range(edtf) && int8range(from, to, '[]')`
  over day numbers,
  so it can use the optional GiST index described in `AshEdtf.Type`.

  Register it in config:

  ```elixir
  config :ash, :custom_expressions, [AshEdtf.Expressions.Overlaps]
  ```
  """
  use Ash.CustomExpression,
    name: :edtf_overlaps,
    arguments: [[AshEdtf.Type, AshEdtf.Day, AshEdtf.Day]]

  def expression(AshPostgres.DataLayer, [edtf, from, to]) do
    {:ok,
     expr(
       fragment(
         "(edtf_range(?) && int8range(?::bigint, ?::bigint, '[]'))",
         ^edtf,
         type(^from, AshEdtf.Day),
         type(^to, AshEdtf.Day)
       )
     )}
  end

  # Ash evaluates a function as `nil` as soon as any argument is `nil`, so the
  # `nil` cases of an open-ended period are handled by `is_nil` / `or` (which
  # short-circuits) and the functions only ever see a value and a date. A
  # literal `nil` bound drops its comparison entirely.
  def expression(data_layer, [edtf, from, to]) when data_layer in [Ash.DataLayer.Ets, Ash.DataLayer.Simple] do
    starts_before_end =
      if is_nil(to),
        do: true,
        else: expr(is_nil(^to) or fragment(&__MODULE__.lower_not_after?/2, ^edtf, ^to))

    ends_after_start =
      if is_nil(from),
        do: true,
        else: expr(is_nil(^from) or fragment(&__MODULE__.upper_not_before?/2, ^edtf, ^from))

    {:ok, expr(not is_nil(^edtf) and ^starts_before_end and ^ends_after_start)}
  end

  def expression(_data_layer, _args), do: :unknown

  @doc "Whether the value's lower bound is on or before `date`; an open or unknown lower bound always is."
  def lower_not_after?(%AshEdtf.Value{lower: nil}, _date), do: true
  def lower_not_after?(%AshEdtf.Value{lower: lower}, date), do: Date.compare(lower, date) != :gt

  @doc "Whether the value's upper bound is on or after `date`; an open or unknown upper bound always is."
  def upper_not_before?(%AshEdtf.Value{upper: nil}, _date), do: true
  def upper_not_before?(%AshEdtf.Value{upper: upper}, date), do: Date.compare(upper, date) != :lt
end
