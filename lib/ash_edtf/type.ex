defmodule AshEdtf.Type do
  @moduledoc """
  Ash type for an EDTF (Extended Date/Time Format) date, stored together with
  the date range it covers.

  Input is an EDTF string. Casting trims it, validates it with `EDTF.parse/1`
  and derives the covered range with `EDTF.to_date_range/1`, producing an
  `AshEdtf.Value`. Blank input (`nil` or whitespace-only) casts to `nil`.

  ```elixir
  attribute :date, AshEdtf.Type
  ```

  ## Data layers

  - **AshPostgres** — the only supported persistent data layer. Requires
    `AshEdtf.AshPostgresExtension` in the repo's `installed_extensions/0`.
  - **Ets / Simple** — supported; the struct is kept in memory and
    `edtf_overlaps/3` is evaluated in Elixir.
  - **Other SQL data layers (e.g. AshSqlite)** — not supported. They have no
    composite type, and storing the value as JSON would make the bounds
    strings, which don't compare correctly for BCE dates.

  ## Storage

  With AshPostgres the value is stored in the `edtf` composite type installed
  by `AshEdtf.AshPostgresExtension`:

  ```sql
  edtf AS (value text, lower bigint, upper bigint,
           lower_bound edtf_bound, upper_bound edtf_bound)
  ```

  Each member is addressable in expressions:

  ```elixir
  filter expr(date[:lower] >= ^~D[1850-01-01])
  sort expr(date[:lower])
  filter expr(date[:upper_bound] != :unknown)
  ```

  Sort by `date[:lower]` rather than by the attribute itself: comparing the
  composite compares the EDTF strings first.

  ## Bounds

  A side whose bound is `:open` or `:unknown` has a `nil` date. `nil` makes
  plain comparisons like `date[:lower] <= ^to` drop the row, so period queries
  should use the `edtf_overlaps/3` expression (`AshEdtf.Expressions.Overlaps`),
  which treats both as unbounded. Add a filter on `date[:lower_bound]` /
  `date[:upper_bound]` to exclude unknown bounds when that is wanted.

  ## Indexing

  Overlap queries go through the immutable `edtf_range(edtf)` SQL function, so
  they can use an optional GiST expression index. Add one only when a table
  is large enough for period searches to need it:

  ```elixir
  postgres do
    custom_indexes do
      index ["edtf_range(date)"], using: "GIST"
    end
  end
  ```

  The planner only uses the index when the query contains the same
  expression, which `edtf_overlaps/3` guarantees. Hand-written fragments
  like `int8range((date).lower, ...)` will not match it.

  ## Limits

  Bounds are stored as day numbers (`AshEdtf.Day`), so every year works,
  including long years like `Y-170000000`. Only day numbers beyond a Postgres
  `bigint` (years around ±25 quadrillion) are rejected.

  ## Working with bounds

  In Elixir, `lower` and `upper` are plain `Date`s. In Postgres they are
  `bigint` day numbers (`Date.to_gregorian_days/1`), so they cover any year.
  Inside Ash this is mostly invisible: comparisons with
  `Date` parameters, sorts, `min`/`max` and `edtf_overlaps/3` just work. It
  shows where a bound meets SQL date handling:

  | Need | Use |
  |---|---|
  | Compare with a date column or `today()` | `date[:lower] <= edtf_day(published_on)` |
  | Year / month / decade, e.g. for grouping | `edtf_year/1`, `edtf_month/1`, `edtf_decade/1` |
  | Calculation or aggregate over a bound | declare the type as `AshEdtf.Day`, not `:date` |
  | Raw SQL | `edtf_day_to_date(bigint)` (within the `date` range), `edtf_day_year`, `edtf_day_month`, `edtf_day_decade`, `edtf_date_to_day(date)` |

  ```elixir
  calculate :earliest_date, AshEdtf.Day, expr(min(dates, expr: date[:lower], expr_type: AshEdtf.Day))
  calculate :decade, :integer, expr(edtf_decade(date[:lower]))
  ```

  Mixing a bound with a real `date` in SQL without converting fails loudly
  (`cannot cast type date to bigint`), never with a wrong result. Prefer
  converting the date side (`edtf_day/1`) over the bound side, so indexes on
  the bound stay usable.

  The expressions must be registered:

  ```elixir
  config :ash, :custom_expressions, [
    AshEdtf.Expressions.Overlaps,
    AshEdtf.Expressions.Day,
    AshEdtf.Expressions.Year,
    AshEdtf.Expressions.Month,
    AshEdtf.Expressions.Decade
  ]
  ```
  """
  use Ash.Type

  alias AshEdtf.Value

  @bounds %{"closed" => :closed, "open" => :open, "unknown" => :unknown}

  @impl true
  def storage_type(_constraints), do: :edtf

  @impl true
  def composite?(_constraints), do: true

  @impl true
  def composite_types(_constraints) do
    [
      {:value, :string, []},
      {:lower, AshEdtf.Day, []},
      {:upper, AshEdtf.Day, []},
      {:lower_bound, AshEdtf.Bound, []},
      {:upper_bound, AshEdtf.Bound, []}
    ]
  end

  @impl true
  def cast_in_query?(_constraints), do: true

  @impl true
  def matches_type?(%Value{}, _constraints), do: true
  def matches_type?(_value, _constraints), do: false

  @impl true
  def equal?(%Value{value: left}, %Value{value: right}), do: left == right
  def equal?(left, right), do: left == right

  @impl true
  def cast_input(nil, _constraints), do: {:ok, nil}
  # Bounds are always re-derived, so a hand-built struct can't smuggle in
  # dates that disagree with its string.
  def cast_input(%Value{value: value}, constraints), do: cast_input(value, constraints)

  def cast_input(value, _constraints) when is_binary(value) do
    case String.trim(value) do
      "" -> {:ok, nil}
      trimmed -> from_string(trimmed, value)
    end
  end

  def cast_input(_value, _constraints), do: {:error, "must be a string"}

  @impl true
  def cast_atomic(value, constraints) do
    if Ash.Expr.expr?(value) do
      {:not_atomic, "EDTF bounds are derived in Elixir, so the value must be a literal"}
    else
      case cast_input(value, constraints) do
        {:ok, value} -> {:atomic, value}
        {:error, error} -> {:error, error}
      end
    end
  end

  @impl true
  def cast_stored(nil, _constraints), do: {:ok, nil}
  def cast_stored(%Value{} = value, _constraints), do: {:ok, value}

  def cast_stored({value, lower, upper, lower_bound, upper_bound}, _constraints) do
    build_stored(value, lower, upper, lower_bound, upper_bound)
  end

  def cast_stored(%{} = map, _constraints) do
    build_stored(
      field(map, :value),
      field(map, :lower),
      field(map, :upper),
      field(map, :lower_bound),
      field(map, :upper_bound)
    )
  end

  def cast_stored(_value, _constraints), do: :error

  @impl true
  def dump_to_native(nil, _constraints), do: {:ok, nil}

  def dump_to_native(%Value{} = v, _constraints) do
    {:ok, {v.value, day(v.lower), day(v.upper), Atom.to_string(v.lower_bound), Atom.to_string(v.upper_bound)}}
  end

  def dump_to_native(_value, _constraints), do: :error

  @impl true
  def dump_to_embedded(nil, _constraints), do: {:ok, nil}

  def dump_to_embedded(%Value{} = v, _constraints) do
    {:ok,
     %{
       "value" => v.value,
       "lower" => v.lower && Date.to_iso8601(v.lower),
       "upper" => v.upper && Date.to_iso8601(v.upper),
       "lower_bound" => Atom.to_string(v.lower_bound),
       "upper_bound" => Atom.to_string(v.upper_bound)
     }}
  end

  def dump_to_embedded(_value, _constraints), do: :error

  defp from_string(trimmed, original) do
    # A lone character parses as a (meaningless) single-digit year; treat it
    # as a typo rather than a date.
    with false <- String.length(trimmed) == 1,
         {:ok, parsed} <- EDTF.parse(trimmed),
         {:ok, {lower, upper}} <- EDTF.DateRange.to_date_range(parsed),
         {:ok, lower, lower_bound} <- side(lower),
         {:ok, upper, upper_bound} <- side(upper) do
      {:ok,
       %Value{
         value: trimmed,
         lower: lower,
         upper: upper,
         lower_bound: lower_bound,
         upper_bound: upper_bound
       }}
    else
      {:error, :out_of_range} ->
        {:error, message: "is outside the supported date range", value: original}

      _ ->
        {:error, message: "is not a valid EDTF date", value: original}
    end
  end

  defp side(%Date{} = date) do
    case AshEdtf.Day.check_range(date) do
      {:ok, date} -> {:ok, date, :closed}
      {:error, _} -> {:error, :out_of_range}
    end
  end

  defp side(:unbounded), do: {:ok, nil, :open}
  defp side(:unknown), do: {:ok, nil, :unknown}

  defp build_stored(value, lower, upper, lower_bound, upper_bound) when is_binary(value) do
    with {:ok, lower} <- stored_date(lower),
         {:ok, upper} <- stored_date(upper),
         {:ok, lower_bound} <- stored_bound(lower_bound),
         {:ok, upper_bound} <- stored_bound(upper_bound) do
      {:ok,
       %Value{
         value: value,
         lower: lower,
         upper: upper,
         lower_bound: lower_bound,
         upper_bound: upper_bound
       }}
    end
  end

  defp build_stored(_value, _lower, _upper, _lower_bound, _upper_bound), do: :error

  defp stored_date(nil), do: {:ok, nil}
  defp stored_date(days) when is_integer(days), do: {:ok, Date.from_gregorian_days(days)}
  defp stored_date(%Date{} = date), do: {:ok, date}

  defp stored_date(iso) when is_binary(iso) do
    case Date.from_iso8601(iso) do
      {:ok, date} -> {:ok, date}
      _ -> :error
    end
  end

  defp stored_date(_date), do: :error

  defp stored_bound(bound) when bound in [:closed, :open, :unknown], do: {:ok, bound}

  defp stored_bound(bound) when is_binary(bound) do
    case Map.fetch(@bounds, bound) do
      {:ok, bound} -> {:ok, bound}
      :error -> :error
    end
  end

  defp stored_bound(_bound), do: :error

  defp day(nil), do: nil
  defp day(%Date{} = date), do: Date.to_gregorian_days(date)

  defp field(map, key), do: Map.get(map, key, Map.get(map, Atom.to_string(key)))
end
