# EDTF in forms (Phoenix)

An `AshEdtf.Value` renders as its EDTF string (`Phoenix.HTML.Safe`,
`String.Chars`, `Jason.Encoder`), so a plain text input works with AshPhoenix
forms. The form submits the string; the type casts it and reports invalid
EDTF as a normal field error.

```heex
<.input field={@form[:date]} type="text" placeholder="e.g. 1850~, 185X, 1850/1860" />
```

## Showing what the input means

`AshEdtf.Phoenix.humanize/1` turns a loaded value, a raw string mid-edit or
an invalid value into its English reading, or `nil`:

```elixir
AshEdtf.Phoenix.humanize("190")        #=> "1900s"
AshEdtf.Phoenix.humanize_field(@form[:date])
```

Use it for a hint next to your own styled input, rather than calling
`EDTF.humanize/1` on `field.value` (which is an `AshEdtf.Value` for loaded
records, not a string).

## Headless component

`AshEdtf.Phoenix.edtf_input/1` renders an unstyled text input plus hint, with
`class`, `input_class`, `hint_class` and a `:hint` slot. `label` (with
`label_class`) adds a `<label>` for the input; the `:label_content` slot
replaces it and receives `%{for: input_id, text: label, examples: examples}`.
Apps with a component
library usually keep their own input and call `humanize_field/1` instead.

## Help for editors

`AshEdtf.Phoenix.examples/0` returns common patterns as
`%{edtf: "1850~", meaning: "approximate", reading: "circa 1850"}` (eight
entries; `reading` comes from `humanize/1`). Use it for a help text in your
own components. `edtf_input/1` renders it with `help={true}` in a native
`<details>` element (`help_class`, `help_label`, and `help_url` /
`help_link_label` for a link); the `:help_content` slot receives the examples
to render them yourself, or the `:label_content` slot receives them to put the
help next to the label (e.g. an icon with a popover; keep the button outside
the `<label>`). Help is off by default. The labels are English, pass
translated ones via the attributes. Order: label, input, reading, help; the
input's `aria-describedby` names only the reading, not the help.

`AshEdtf.Phoenix` is only compiled when `phoenix_live_view` is a dependency.
