defmodule AshEdtf.EtsTest do
  use ExUnit.Case, async: true

  import Ash.Expr

  alias AshEdtf.Test.EtsEvent, as: Event

  setup do
    for date <- ["1850", "1840/", "1900/", "../1800"] do
      Event
      |> Ash.Changeset.for_create(:create, %{date: date})
      |> Ash.create!()
    end

    :ok
  end

  defp dates_matching(filter) do
    Event
    |> Ash.Query.do_filter(filter)
    |> Ash.read!()
    |> Enum.map(&to_string(&1.date))
    |> Enum.sort()
  end

  test "stores and loads the value" do
    assert dates_matching(expr(true)) == ["../1800", "1840/", "1850", "1900/"]
  end

  test "filters on composite members" do
    assert dates_matching(expr(date[:upper_bound] == :unknown)) == ["1840/", "1900/"]
  end

  test "evaluates edtf_overlaps/3 in Elixir" do
    assert dates_matching(expr(edtf_overlaps(date, ^~D[1850-12-31], ^~D[1860-01-01]))) == ["1840/", "1850"]
    assert dates_matching(expr(edtf_overlaps(date, nil, ^~D[1700-01-01]))) == ["../1800"]
  end

  test "evaluates edtf_year/1, edtf_month/1 and edtf_decade/1 in Elixir" do
    assert dates_matching(expr(edtf_year(date[:lower]) == 1850)) == ["1850"]

    assert dates_matching(expr(edtf_month(date[:upper]) == 12 and edtf_decade(date[:upper]) == 1800)) ==
             ["../1800"]
  end

  test "evaluates edtf_day/1 in Elixir" do
    assert dates_matching(expr(date[:upper] <= edtf_day(today()))) == ["../1800", "1850"]
  end
end
