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
end
