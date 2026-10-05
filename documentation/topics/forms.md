# Forms

An `AshEdtf.Value` renders as its EDTF string (`Phoenix.HTML.Safe`), so an
`AshPhoenix.Form` text input shows and submits it like any string. Invalid
EDTF comes back as a normal field error.

```heex
<.input field={@form[:date]} type="text" label="Date (EDTF)" placeholder="1850~, 185X, 1850/1860" />
```

## Showing the reading

`AshEdtf.Phoenix.humanize/1` returns the English reading of a loaded value, a
raw string mid-edit, or `nil` when the input isn't valid EDTF:

```elixir
AshEdtf.Phoenix.humanize("190")          #=> "1900s"
AshEdtf.Phoenix.humanize("1850/..")      #=> "from 1850"
AshEdtf.Phoenix.humanize("not a date")   #=> nil
```

`humanize_field/1` does the same for a form field, so the hint follows the
input on every `phx-change`:

```heex
<.input field={@form[:date]} type="text" label="Date (EDTF)" />
<p class="hint">{AshEdtf.Phoenix.humanize_field(@form[:date])}</p>
```

## Headless component

`AshEdtf.Phoenix.edtf_input/1` renders a text input with its reading and no
built-in styling:

```heex
<AshEdtf.Phoenix.edtf_input
  field={@form[:date]}
  class="field"
  input_class="input"
  hint_class="hint"
/>
```

Use the `:hint` slot to render the reading yourself:

```heex
<AshEdtf.Phoenix.edtf_input field={@form[:date]}>
  <:hint :let={reading}>
    <small :if={reading}>{reading}</small>
  </:hint>
</AshEdtf.Phoenix.edtf_input>
```

`AshEdtf.Phoenix` is compiled only when `phoenix_live_view` is a dependency.
