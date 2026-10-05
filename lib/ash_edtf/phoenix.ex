if Code.ensure_loaded?(Phoenix.Component) do
  defmodule AshEdtf.Phoenix do
    @moduledoc """
    Unstyled form helpers for `AshEdtf.Type` fields.

    `humanize/1` and `humanize_field/1` turn whatever a form currently holds
    (a loaded `AshEdtf.Value`, a raw string mid-edit, or garbage) into the
    English reading of the date, or `nil`. Apps with their own input
    components can call these for the hint and keep their own markup.

    `edtf_input/1` is a minimal text input plus hint with no classes baked in.
    """
    use Phoenix.Component

    alias Phoenix.HTML.FormField

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

    attr(:rest, :global, include: ~w(autocomplete disabled form maxlength minlength pattern readonly required tabindex))

    slot(:hint,
      doc: "custom hint rendering; receives the humanized string (or nil) as its argument"
    )

    @doc """
    Renders a text input for an EDTF field with its humanized reading.

    The input belongs to the parent form, so validation and errors come from
    the form as usual. The hint updates on every `phx-change`.
    """
    def edtf_input(assigns) do
      assigns = assign(assigns, :humanized, humanize_field(assigns.field))

      ~H"""
      <div class={@class}>
        <%= if @hint != [] do %>
          {render_slot(@hint, @humanized)}
        <% else %>
          <p class={@hint_class} id={"#{@id || @field.id}-hint"}>{@humanized}</p>
        <% end %>
        <input
          type="text"
          id={@id || @field.id}
          name={@field.name}
          value={Phoenix.HTML.Form.normalize_value("text", @field.value)}
          class={@input_class}
          placeholder={@placeholder}
          aria-describedby={@hint == [] && "#{@id || @field.id}-hint"}
          {@rest}
        />
      </div>
      """
    end
  end
end
