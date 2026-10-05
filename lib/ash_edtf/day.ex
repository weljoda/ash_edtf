defmodule AshEdtf.Day do
  @moduledoc """
  A calendar day without a range limit: a `Date` in Elixir, stored as its
  day number (`Date.to_gregorian_days/1`) in a `bigint`.

  Used for the `lower` / `upper` members of the `edtf` composite. Postgres
  `date` stops at 4713 BC, while EDTF allows years like `Y-170000000`; day
  numbers keep their order, so comparisons stay exact for any year.

  Expressions take `Date`s and dump them to day numbers:

  ```elixir
  filter expr(date[:lower] >= ^~D[1850-01-01])
  ```

  In raw SQL, convert with `edtf_day_to_date(bigint)` (inside the Postgres
  `date` range) or `edtf_day_year(bigint)` (any year).
  """
  use Ash.Type

  # Day numbers must fit a Postgres bigint.
  @max_days 9_223_372_036_854_775_807

  @impl true
  def storage_type(_constraints), do: :bigint

  @impl true
  def cast_in_query?(_constraints), do: true

  @impl true
  def matches_type?(%Date{}, _constraints), do: true
  def matches_type?(_value, _constraints), do: false

  @impl true
  def cast_input(nil, _constraints), do: {:ok, nil}
  def cast_input(%Date{calendar: Calendar.ISO} = date, _constraints), do: check_range(date)

  def cast_input(value, _constraints) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> check_range(date)
      _ -> {:error, "is not a valid date"}
    end
  end

  def cast_input(_value, _constraints), do: {:error, "is not a valid date"}

  @impl true
  def cast_stored(nil, _constraints), do: {:ok, nil}
  def cast_stored(days, _constraints) when is_integer(days), do: {:ok, Date.from_gregorian_days(days)}
  def cast_stored(%Date{} = date, _constraints), do: {:ok, date}
  def cast_stored(_value, _constraints), do: :error

  @impl true
  def dump_to_native(nil, _constraints), do: {:ok, nil}
  def dump_to_native(%Date{} = date, _constraints), do: {:ok, Date.to_gregorian_days(date)}
  def dump_to_native(_value, _constraints), do: :error

  @doc "Returns `{:ok, date}` when the date's day number fits a bigint."
  def check_range(%Date{} = date) do
    if abs(Date.to_gregorian_days(date)) <= @max_days,
      do: {:ok, date},
      else: {:error, "is outside the supported range"}
  end
end
