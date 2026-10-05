defmodule AshEdtf.PhoenixTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Phoenix.HTML.FormField

  defp field(value) do
    %FormField{} = field = Phoenix.Component.to_form(%{"date" => value}, as: :doc)[:date]
    %{field | value: value}
  end

  describe "humanize/1" do
    test "humanizes loaded values and raw strings alike" do
      {:ok, value} = Ash.Type.cast_input(AshEdtf.Type, "1999-06-10", [])

      assert AshEdtf.Phoenix.humanize(value) == "June 10, 1999"
      assert AshEdtf.Phoenix.humanize(" 1999-06-10 ") == "June 10, 1999"
    end

    test "returns nil for blank, invalid and non-string values" do
      assert AshEdtf.Phoenix.humanize("  ") == nil
      assert AshEdtf.Phoenix.humanize("not a date") == nil
      assert AshEdtf.Phoenix.humanize(nil) == nil
    end
  end

  describe "edtf_input/1" do
    test "renders the EDTF string as the input value with its reading" do
      {:ok, value} = Ash.Type.cast_input(AshEdtf.Type, "190", [])

      html = render_component(&AshEdtf.Phoenix.edtf_input/1, field: field(value), input_class: "x")

      assert html =~ ~s(value="190")
      assert html =~ ~s(name="doc[date]")
      assert html =~ "1900s"
      assert html =~ ~s(aria-describedby="doc_date-hint")
    end
  end
end
