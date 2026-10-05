defmodule AshEdtf.TypeTest do
  use ExUnit.Case, async: true

  alias AshEdtf.Value
  alias Phoenix.HTML.Safe

  defp cast(input), do: Ash.Type.cast_input(AshEdtf.Type, input, [])

  describe "cast_input/2" do
    test "derives closed bounds from an exact date" do
      assert {:ok,
              %Value{
                value: "1984-06-15",
                lower: ~D[1984-06-15],
                upper: ~D[1984-06-15],
                lower_bound: :closed,
                upper_bound: :closed
              }} = cast("1984-06-15")
    end

    test "spans the full year for a year-only date" do
      assert {:ok, %Value{lower: ~D[1984-01-01], upper: ~D[1984-12-31]}} = cast("1984")
    end

    test "trims whitespace and keeps the trimmed string" do
      assert {:ok, %Value{value: "1984-06-15"}} = cast("  1984-06-15  ")
    end

    test "casts blank input to nil" do
      assert {:ok, nil} = cast(nil)
      assert {:ok, nil} = cast("")
      assert {:ok, nil} = cast("   ")
    end

    test "marks explicitly open sides as :open" do
      assert {:ok, %Value{lower: ~D[1984-01-01], upper: nil, upper_bound: :open}} = cast("1984/..")
      assert {:ok, %Value{lower: nil, lower_bound: :open, upper: ~D[1984-12-31]}} = cast("../1984")
      assert {:ok, %Value{lower: nil, lower_bound: :open, upper_bound: :closed}} = cast("[..1984]")
    end

    test "marks empty sides as :unknown" do
      assert {:ok, %Value{upper: nil, upper_bound: :unknown, lower_bound: :closed}} = cast("1984/")
      assert {:ok, %Value{lower: nil, lower_bound: :unknown, upper_bound: :closed}} = cast("/1984")
    end

    test "re-derives bounds from a struct's string" do
      forged = %Value{value: "1984", lower: ~D[2000-01-01], upper: nil, lower_bound: :open, upper_bound: :open}

      assert {:ok, %Value{lower: ~D[1984-01-01], upper: ~D[1984-12-31], lower_bound: :closed}} =
               cast(forged)
    end

    test "rejects invalid EDTF, single characters and non-strings" do
      assert {:error, _} = cast("not-a-date")
      assert {:error, _} = cast("1")
      assert {:error, _} = cast("1999-02-30")
      assert {:error, _} = cast(1984)
    end

    test "accepts years beyond the Postgres date range" do
      assert {:ok, %Value{lower: lower, upper: upper}} = cast("Y-170000000")
      assert lower == Date.new!(-170_000_000, 1, 1)
      assert upper == Date.new!(-170_000_000, 12, 31)
    end
  end

  describe "storage" do
    test "round-trips through the composite tuple" do
      {:ok, value} = cast("../1984-06")
      {:ok, dumped} = Ash.Type.dump_to_native(AshEdtf.Type, value, [])

      assert dumped == {"../1984-06", nil, Date.to_gregorian_days(~D[1984-06-30]), "open", "closed"}
      assert {:ok, ^value} = Ash.Type.cast_stored(AshEdtf.Type, dumped, [])
    end

    test "round-trips through the embedded map" do
      {:ok, value} = cast("1984/")
      {:ok, dumped} = Ash.Type.dump_to_embedded(AshEdtf.Type, value, [])

      assert {:ok, ^value} = Ash.Type.cast_stored(AshEdtf.Type, dumped, [])
    end
  end

  describe "rendering" do
    test "renders as the EDTF string" do
      {:ok, value} = cast("1984~")

      assert to_string(value) == "1984~"
      assert Safe.to_iodata(value) == "1984~"
      assert Jason.encode!(value) == ~s("1984~")
    end
  end
end
