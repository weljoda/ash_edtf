defmodule AshEdtf.PostgresTest do
  @moduledoc """
  Postgres behaviour of `AshEdtf.Type`: storage in the `edtf` composite,
  filters on its members and `edtf_overlaps/3`.
  """
  use AshEdtf.DataCase, async: false

  setup do
    %{document: create_document!()}
  end

  test "stores and loads the EDTF string with its bounds", %{document: document} do
    created = add_date!(document, " ../1850-06 ")

    assert [%{date: date}] =
             DocumentDate
             |> Ash.Query.filter(id == ^created.id)
             |> Ash.read!()

    assert %AshEdtf.Value{
             value: "../1850-06",
             lower: nil,
             upper: ~D[1850-06-30],
             lower_bound: :open,
             upper_bound: :closed
           } = date
  end

  test "filters on composite members", %{document: document} do
    add_date!(document, "1850")
    add_date!(document, "1900/")
    add_date!(document, "1950-03-01")

    assert dates_matching(document, expr(date[:lower] >= ^~D[1900-01-01])) == ["1900/", "1950-03-01"]
    assert dates_matching(document, expr(date[:upper_bound] == :unknown)) == ["1900/"]
  end

  test "edtf_overlaps/3 treats open and unknown bounds as unbounded", %{document: document} do
    add_date!(document, "1850")
    add_date!(document, "1840/")
    add_date!(document, "1900/")
    add_date!(document, "../1800")

    assert dates_matching(document, expr(edtf_overlaps(date, ^~D[1850-12-31], ^~D[1860-01-01]))) ==
             ["1840/", "1850"]

    assert dates_matching(document, expr(edtf_overlaps(date, nil, ^~D[1700-01-01]))) == ["../1800"]
  end

  describe "sorting" do
    setup %{document: document} do
      for date <- ["1900", "Y-170000000", "1850"], do: add_date!(document, date)
      :ok
    end

    defp sorted(document, sort) do
      DocumentDate
      |> Ash.Query.filter(document_id == ^document.id)
      |> Ash.Query.sort(sort)
      |> Ash.read!()
      |> Enum.map(&to_string(&1.date))
    end

    test "expr_sort on a bound orders by date", %{document: document} do
      require Ash.Sort

      assert sorted(document, Ash.Sort.expr_sort(date[:lower], AshEdtf.Day)) == ["Y-170000000", "1850", "1900"]

      assert sorted(document, [{Ash.Sort.expr_sort(date[:lower], AshEdtf.Day), :desc}]) ==
               ["1900", "1850", "Y-170000000"]
    end

    test "a bound calculation orders by date", %{document: document} do
      assert sorted(document, start_date: :asc) == ["Y-170000000", "1850", "1900"]
    end

    test "sorting by the attribute orders by the EDTF string", %{document: document} do
      assert sorted(document, :date) == ["1850", "1900", "Y-170000000"]
      assert sorted(document, date: [:lower]) == ["1850", "1900", "Y-170000000"]
    end
  end

  test "the raw SQL example from the Postgres guide", %{document: document} do
    add_date!(document, "1855")
    add_date!(document, "1870")

    %{rows: rows} =
      Repo.query!("""
      SELECT (date).value, edtf_day_year((date).lower), edtf_day_to_date((date).upper)
      FROM document_dates
      WHERE edtf_range(date) && int8range(edtf_date_to_day('1850-01-01'), edtf_date_to_day('1859-12-31'), '[]')
      """)

    assert rows == [["1855", 1855, ~D[1855-12-31]]]
  end
end
