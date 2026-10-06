defmodule AshEdtf.PhoenixTest do
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest

  doctest AshEdtf.Phoenix

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

    test "reads decades and open intervals" do
      assert AshEdtf.Phoenix.humanize("190") == "1900s"
      assert AshEdtf.Phoenix.humanize("1850/..") == "from 1850"
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

    test "renders the label, the input, the reading and the help in that order" do
      html =
        render_component(&AshEdtf.Phoenix.edtf_input/1,
          field: field("185X"),
          label: "Date",
          help: true
        )

      positions = Enum.map(["<label", "<input", "1850s</p>", "<details"], &:binary.match(html, &1))

      assert Enum.all?(positions, &match?({_, _}, &1))
      assert positions == Enum.sort(positions)
    end

    test "renders no help by default" do
      html = render_component(&AshEdtf.Phoenix.edtf_input/1, field: field("1850"))

      refute html =~ "<details"
    end

    test "help renders the examples in a details element with an optional link" do
      html =
        render_component(&AshEdtf.Phoenix.edtf_input/1,
          field: field("1850"),
          help: true,
          help_class: "help",
          help_url: "https://example.com/edtf"
        )

      assert html =~ ~s(<details id="doc_date-help" class="help">)
      assert html =~ ~s(aria-describedby="doc_date-hint")
      assert html =~ "<summary>EDTF help</summary>"
      assert html =~ "<code>1850~</code>"
      assert html =~ "approximate: circa 1850"
      assert html =~ ~s(href="https://example.com/edtf")
      assert html =~ "Full EDTF reference"

      refute render_component(&AshEdtf.Phoenix.edtf_input/1, field: field("1850"), help: true) =~
               "<a "
    end

    test "the help_content slot renders the examples itself" do
      assigns = %{field: field("1850")}

      html =
        rendered_to_string(~H"""
        <AshEdtf.Phoenix.edtf_input field={@field}>
          <:help_content :let={examples}>
            <ul>
              <li :for={example <- examples}><code>{example.edtf}</code> {example.reading}</li>
            </ul>
          </:help_content>
        </AshEdtf.Phoenix.edtf_input>
        """)

      assert html =~ "<li><code>185X</code> 1850s</li>"
      refute html =~ "<details"
    end
  end

  describe "edtf_input/1 label" do
    test "renders no label by default" do
      refute render_component(&AshEdtf.Phoenix.edtf_input/1, field: field("1850")) =~ "<label"
    end

    test "label renders a label for the input" do
      html =
        render_component(&AshEdtf.Phoenix.edtf_input/1,
          field: field("1850"),
          label: "Date",
          label_class: "lbl"
        )

      assert html =~ ~s(<label for="doc_date" class="lbl">Date</label>)
    end

    test "the label_content slot receives the input id, label and examples" do
      assigns = %{field: field("1850")}

      html =
        rendered_to_string(~H"""
        <AshEdtf.Phoenix.edtf_input field={@field} id="custom" label="Date">
          <:label_content :let={label}>
            <label for={label.for}>{label.text}</label>
            <span>{length(label.examples)} examples</span>
          </:label_content>
        </AshEdtf.Phoenix.edtf_input>
        """)

      assert html =~ ~s(<label for="custom">Date</label>)
      assert html =~ "<span>8 examples</span>"
      assert html =~ ~s(id="custom")
      refute html =~ "<details"
    end
  end

  describe "examples/0" do
    test "every example is valid EDTF with a reading" do
      examples = AshEdtf.Phoenix.examples()

      assert length(examples) == 8

      for %{edtf: edtf, meaning: meaning, reading: reading} <- examples do
        assert {:ok, _} = Ash.Type.cast_input(AshEdtf.Type, edtf, [])
        assert is_binary(meaning) and is_binary(reading)
      end
    end
  end
end
