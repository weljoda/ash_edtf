defmodule AshEdtf.Type do
  @moduledoc """
  Ash type for an EDTF (Extended Date/Time Format) date, stored together with
  the date range it covers.

  ```elixir
  attribute :date, AshEdtf.Type      # or :edtf when registered as a custom type
  ```

  Input is an EDTF string. Casting trims it, parses it with `EDTF.parse/1` and
  derives the covered range with `EDTF.to_date_range/1`, producing an
  `AshEdtf.Value`. Blank input (`nil` or whitespace-only) casts to `nil`;
  invalid input is an error ("is not a valid EDTF date").

  ## Storage

  With AshPostgres the value is one column of the `edtf` composite type
  installed by `AshEdtf.AshPostgresExtension`. Its fields are addressable in
  expressions:

  | Field | Type |
  |---|---|
  | `:value` | `:string` — the EDTF string |
  | `:lower`, `:upper` | `AshEdtf.Day` — first / last day covered, `nil` unless the side is `:closed` |
  | `:lower_bound`, `:upper_bound` | `AshEdtf.Bound` — `:closed`, `:open`, `:unknown` |

  ```elixir
  filter expr(date[:lower] >= ^~D[1850-01-01])
  filter expr(edtf_overlaps(date, ^from, ^to))
  ```

  Bounds are `Date`s in Elixir and day numbers in Postgres, so every year
  works. Only day numbers beyond a Postgres `bigint` (years around
  ±25 quadrillion) are rejected.

  ## Data layers

  AshPostgres is the supported persistent data layer. With `Ash.DataLayer.Ets`
  and `Ash.DataLayer.Simple` values are kept as structs and the AshEdtf
  expressions are evaluated in Elixir. Data layers without composite types
  (e.g. AshSqlite) are not supported.

  ## Guides

  - [EDTF values](edtf-values.md) — what each input stores, bounds, rejected input
  - [Querying](querying.md) — period search, comparisons, sorting, calendar parts, aggregates
  - [Postgres](postgres.md) — installed objects, indexing, raw SQL
  - [Forms](forms.md)
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
