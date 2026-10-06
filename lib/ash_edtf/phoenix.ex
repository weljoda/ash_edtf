if Code.ensure_loaded?(Phoenix.Component) do
  defmodule AshEdtf.Phoenix do
    @moduledoc """
    Unstyled form helpers for `AshEdtf.Type` fields.

    `humanize/1` and `humanize_field/1` turn whatever a form currently holds
    (a loaded `AshEdtf.Value`, a raw string mid-edit, or garbage) into the
    English reading of the date, or `nil`. Apps with their own input
    components can call these for the hint and keep their own markup.

    `edtf_input/1` is a minimal labelled text input plus hint with no classes
    baked in.
    `examples/0` lists common EDTF patterns for help texts; `edtf_input/1`
    renders them on request.
    """
    use Phoenix.Component

    alias Phoenix.HTML.FormField

    @examples [
      {"1850-06-15", "exact day"},
      {"1850-06", "month"},
      {"1850~", "approximate"},
      {"1850?", "uncertain"},
      {"185X", "decade"},
      {"1850/1860", "range"},
      {"../1850", "open start"},
      {"1850/..", "open end"}
    ]

    @doc """
    Returns common EDTF patterns for help texts.

    Each example has the EDTF string, a short English label of what it
    expresses, and its reading from `humanize/1`:

        iex> AshEdtf.Phoenix.examples() |> Enum.find(&(&1.edtf == "1850~"))
        %{edtf: "1850~", meaning: "approximate", reading: "circa 1850"}
    """
    @spec examples() :: [%{edtf: String.t(), meaning: String.t(), reading: String.t()}]
    def examples do
      Enum.map(@examples, fn {edtf, meaning} ->
        %{edtf: edtf, meaning: meaning, reading: humanize(edtf)}
      end)
    end

    @doc """
    Returns the humanized reading of an EDTF value, or `nil` when the value
    is blank or not valid EDTF.
    """
    @spec humanize(term()) :: String.t() | nil
    def humanize(%AshEdtf.Value{value: value}), do: humanize(value)

    def humanize(value) when is_binary(value) do
      case String.trim(value) do
        "" ->
          nil

        trimmed ->
          case EDTF.humanize(trimmed) do
            humanized when is_binary(humanized) -> humanized
            _ -> nil
          end
      end
    end

    def humanize(_value), do: nil

    @doc """
    Returns the humanized reading of a form field's current value.
    """
    @spec humanize_field(FormField.t()) :: String.t() | nil
    def humanize_field(%FormField{value: value}), do: humanize(value)

    attr(:field, FormField, required: true)
    attr(:id, :string, default: nil)
    attr(:class, :any, default: nil, doc: "classes for the wrapper element")
    attr(:input_class, :any, default: nil)
    attr(:hint_class, :any, default: nil)
    attr(:placeholder, :string, default: nil)
    attr(:label, :string, default: nil, doc: "text of a `<label>` rendered above the input")
    attr(:label_class, :any, default: nil)

    attr(:rest, :global, include: ~w(autocomplete disabled form maxlength minlength pattern readonly required tabindex))

    attr(:help, :boolean, default: false, doc: "render the `examples/0` in a `<details>` below the input")
    attr(:help_url, :string, default: nil, doc: "link to further EDTF documentation, shown in the help")
    attr(:help_class, :any, default: nil, doc: "classes for the `<details>` element")
    attr(:help_label, :string, default: "EDTF help", doc: "text of the `<summary>`")
    attr(:help_link_label, :string, default: "Full EDTF reference")

    slot(:hint,
      doc: "custom hint rendering; receives the humanized string (or nil) as its argument"
    )

    slot(:label_content,
      doc: """
      custom label rendering, shown instead of the default `<label>`; receives
      `%{for: input_id, text: label, examples: examples/0}`, e.g. to put a help
      popover next to the label
      """
    )

    slot(:help_content,
      doc: "custom help rendering, shown instead of the default help; receives `examples/0` as its argument"
    )

    @doc """
    Renders a text input for an EDTF field with its humanized reading.

    With `label`, a `<label>` for the input comes first. The `:label_content`
    slot replaces it and receives the input id, the label text and
    `examples/0`, so the label row can also hold the help, e.g. as an icon
    with a popover.

    The input belongs to the parent form, so validation and errors come from
    the form as usual. The hint updates on every `phx-change`.

    With `help={true}`, common patterns from `examples/0` follow the input in
    a native `<details>` element (no JavaScript, keyboard and screen reader
    accessible), plus a link when `help_url` is set. The help is the next
    element after the input, not part of its `aria-describedby`, so screen
    readers don't read all examples on every focus. Use the `:help_content`
    slot to render the examples yourself; it implies `help`.
    """
    def edtf_input(assigns) do
      id = assigns.id || assigns.field.id
      help? = assigns.help and assigns.help_content == []

      assigns =
        assigns
        |> assign(:input_id, id)
        |> assign(:help?, help?)
        |> assign(:humanized, humanize_field(assigns.field))
        |> assign(:examples, if(needs_examples?(assigns), do: examples(), else: []))

      ~H"""
      <div class={@class}>
        <%= if @label_content != [] do %>
          {render_slot(@label_content, %{for: @input_id, text: @label, examples: @examples})}
        <% else %>
          <label :if={@label} for={@input_id} class={@label_class}>{@label}</label>
        <% end %>
        <input
          type="text"
          id={@input_id}
          name={@field.name}
          value={Phoenix.HTML.Form.normalize_value("text", @field.value)}
          class={@input_class}
          placeholder={@placeholder}
          aria-describedby={@hint == [] && "#{@input_id}-hint"}
          {@rest}
        />
        <%= if @hint != [] do %>
          {render_slot(@hint, @humanized)}
        <% else %>
          <p class={@hint_class} id={"#{@input_id}-hint"}>{@humanized}</p>
        <% end %>
        {render_slot(@help_content, @examples)}
        <details :if={@help?} id={"#{@input_id}-help"} class={@help_class}>
          <summary>{@help_label}</summary>
          <dl>
            <%= for example <- @examples do %>
              <dt><code>{example.edtf}</code></dt>
              <dd>{example.meaning}: {example.reading}</dd>
            <% end %>
          </dl>
          <a :if={@help_url} href={@help_url} target="_blank" rel="noopener noreferrer">
            {@help_link_label}
          </a>
        </details>
      </div>
      """
    end

    defp needs_examples?(assigns) do
      assigns.help or assigns.help_content != [] or assigns.label_content != []
    end
  end
end
