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
`class`, `input_class`, `hint_class` and a `:hint` slot. Apps with a component
library usually keep their own input and call `humanize_field/1` instead.

`AshEdtf.Phoenix` is only compiled when `phoenix_live_view` is a dependency.
