defmodule AshEdtf.DayTest do
  @moduledoc """
  Bounds stored as bigint day numbers (`AshEdtf.Day`): range, Ash
  expressions and the SQL helper functions.
  """
  use AshEdtf.DataCase, async: false

  alias Ash.Error.Unknown

  # Leap days, the year-0 boundary, the old Postgres minimum and far years.
  @calendar_edge_cases [
    ~D[0000-01-01],
    ~D[0000-02-29],
    ~D[0000-03-01],
    ~D[-0001-12-31],
    ~D[1900-02-28],
    ~D[2000-02-29],
    ~D[1850-12-31],
    ~D[1851-01-01],
    ~D[-1845-06-01],
    ~D[-1840-01-01],
    ~D[-4713-01-01],
    ~D[9999-12-31],
    Date.new!(-170_000_000, 1, 1),
    Date.new!(-170_000_000, 12, 31),
    Date.new!(170_000_000, 3, 1)
  ]

  setup do
    %{document: create_document!()}
  end

  defp sql!(statement, params) do
    %{rows: [[value]]} = Repo.query!(statement, params)
    value
  end

  describe "storage" do
    test "long years round-trip through Postgres", %{document: document} do
      created = add_date!(document, "Y-170000000")

      assert [%{date: date}] =
               DocumentDate |> Ash.Query.filter(id == ^created.id) |> Ash.read!()

      assert date.lower == Date.new!(-170_000_000, 1, 1)
      assert date.upper == Date.new!(-170_000_000, 12, 31)
    end

    test "member filters take Date params on both sides of the Postgres date range", %{document: document} do
      add_date!(document, "Y-170000000")
      add_date!(document, "-5000")
      add_date!(document, "1850")

      assert dates_matching(document, expr(date[:lower] >= ^~D[1800-01-01])) == ["1850"]
      assert dates_matching(document, expr(date[:upper] < ^Date.new!(-4800, 1, 1))) == ["-5000", "Y-170000000"]
      assert dates_matching(document, expr(date[:lower] < ^Date.new!(-1_000_000, 1, 1))) == ["Y-170000000"]
    end

    test "edtf_overlaps/3 works with periods beyond the Postgres date range", %{document: document} do
      add_date!(document, "Y-170000000")
      add_date!(document, "-5000/-4000")
      add_date!(document, "1850")

      assert dates_matching(
               document,
               expr(edtf_overlaps(date, ^Date.new!(-4500, 1, 1), ^Date.new!(-4400, 1, 1)))
             ) == ["-5000/-4000"]

      assert dates_matching(document, expr(edtf_overlaps(date, nil, ^Date.new!(-100_000_000, 1, 1)))) ==
               ["Y-170000000"]
    end

    test "aggregates over a bound return Dates", %{document: document} do
      add_date!(document, "1850")
      add_date!(document, "Y-170000000")

      loaded = Ash.load!(document, :earliest_date)

      assert loaded.earliest_date == Date.new!(-170_000_000, 1, 1)
    end
  end

  describe "SQL helpers" do
    test "edtf_day_year/month/decade match Elixir for any day" do
      for date <- @calendar_edge_cases do
        days = Date.to_gregorian_days(date)

        assert sql!("SELECT edtf_day_year($1)", [days]) == date.year, "year of #{inspect(date)}"
        assert sql!("SELECT edtf_day_month($1)", [days]) == date.month, "month of #{inspect(date)}"

        assert sql!("SELECT edtf_day_decade($1)", [days]) == Integer.floor_div(date.year, 10) * 10,
               "decade of #{inspect(date)}"
      end
    end

    test "every day of a leap year and its neighbours maps to the right month" do
      for date <- Date.range(~D[-0001-12-25], ~D[0001-01-05]) do
        days = Date.to_gregorian_days(date)
        assert sql!("SELECT (edtf_day_parts($1)).day_of_month", [days]) == date.day, inspect(date)
        assert sql!("SELECT edtf_day_month($1)", [days]) == date.month, inspect(date)
      end
    end

    test "edtf_date_to_day/1 and edtf_day_to_date/1 agree with Elixir" do
      for date <- [~D[1850-06-15], ~D[0000-01-01], ~D[-4712-11-24], ~D[2000-01-01]] do
        days = Date.to_gregorian_days(date)
        assert sql!("SELECT edtf_date_to_day($1)", [date]) == days
        assert sql!("SELECT edtf_day_to_date($1)", [days]) == date
      end
    end

    test "Postgres date functions don't work on bounds directly", %{document: document} do
      add_date!(document, "1850")

      assert_raise Unknown, ~r/does not exist/, fn ->
        dates_matching(document, expr(fragment("extract(year from ?)", date[:lower]) == 1850))
      end

      assert_raise Unknown, ~r/cannot cast type date to bigint/, fn ->
        dates_matching(document, expr(date[:lower] <= fragment("CURRENT_DATE")))
      end
    end
  end

  describe "Ash expressions" do
    test "edtf_year/1, edtf_month/1 and edtf_decade/1", %{document: document} do
      add_date!(document, "1850-06")
      add_date!(document, "-1845")
      add_date!(document, "Y-170000000")

      assert dates_matching(document, expr(edtf_year(date[:lower]) == 1850)) == ["1850-06"]
      assert dates_matching(document, expr(edtf_month(date[:lower]) == 6)) == ["1850-06"]
      assert dates_matching(document, expr(edtf_decade(date[:upper]) == -1850)) == ["-1845"]
      assert dates_matching(document, expr(edtf_year(date[:lower]) == -170_000_000)) == ["Y-170000000"]
    end

    test "edtf_day/1 compares bounds with date expressions", %{document: document} do
      add_date!(document, "1850")
      add_date!(document, "2999")

      assert dates_matching(document, expr(date[:upper] <= edtf_day(today()))) == ["1850"]
      assert dates_matching(document, expr(date[:lower] > edtf_day(today()))) == ["2999"]
    end
  end
end
