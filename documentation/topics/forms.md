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

`AshEdtf.Phoenix.edtf_input/1` renders a labelled text input with its
reading and no built-in styling:

```heex
<AshEdtf.Phoenix.edtf_input
  field={@form[:date]}
  label="Date (EDTF)"
  class="field"
  label_class="label"
  input_class="input"
  hint_class="hint"
/>
```

The label is optional; without `label` the component renders none.

Use the `:hint` slot to render the reading yourself:

```heex
<AshEdtf.Phoenix.edtf_input field={@form[:date]}>
  <:hint :let={reading}>
    <small :if={reading}>{reading}</small>
  </:hint>
</AshEdtf.Phoenix.edtf_input>
```

## Help for editors

EDTF notation is new to most editors. `help={true}` adds common patterns
below the input, in a native `<details>` element that needs no JavaScript and
works with keyboard and screen readers:

```heex
<AshEdtf.Phoenix.edtf_input
  field={@form[:date]}
  help
  help_class="edtf-help"
  help_url="https://www.loc.gov/standards/datetime/"
/>
```

It shows each example with what it expresses and its reading, e.g.
`1850~` — "approximate: circa 1850", `185X` — "decade: 1850s". The link is
optional and has no default: point it at whatever suits your editors, e.g. an
internal help page. `help_label` and `help_link_label` replace the English
texts.

The help follows the input and its reading. The input's `aria-describedby`
names only the reading, so screen readers don't read all examples on every
focus; the help is the next element in the tab order.

The examples come from `AshEdtf.Phoenix.examples/0`, so you can render them
in your own components (a tooltip, a modal), or through the `:help_content`
slot:

```heex
<AshEdtf.Phoenix.edtf_input field={@form[:date]}>
  <:help_content :let={examples}>
    <ul>
      <li :for={example <- examples}><code>{example.edtf}</code> {example.reading}</li>
    </ul>
  </:help_content>
</AshEdtf.Phoenix.edtf_input>
```

To show the help next to the label, e.g. as an info icon with a popover,
use the `:label_content` slot. It replaces the default `<label>` and receives
the input id, the label text and the examples:

```heex
<AshEdtf.Phoenix.edtf_input field={@form[:date]} label="Date (EDTF)">
  <:label_content :let={label}>
    <div class="label-row">
      <label for={label.for}>{label.text}</label>
      <.my_help_popover examples={label.examples} />
    </div>
  </:label_content>
</AshEdtf.Phoenix.edtf_input>
```

Keep interactive elements such as the popover button outside the `<label>`:
a click inside a label focuses the input.

`AshEdtf.Phoenix` is compiled only when `phoenix_live_view` is a dependency.
