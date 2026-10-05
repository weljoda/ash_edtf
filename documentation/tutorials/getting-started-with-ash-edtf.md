# Getting Started with AshEdtf

This guide adds an EDTF date to an Ash resource, queries it and shows it in a
form. It assumes an Ash application using AshPostgres.

## What you get

[EDTF](https://www.loc.gov/standards/datetime/) (Extended Date/Time Format,
ISO 8601-2) expresses the dates that historical and archival data actually
has: uncertain (`1850?`), approximate (`1850~`), partly unknown (`185X`),
ranges (`1850/1860`), open-ended (`../1850`) and very old (`Y-170000000`).

An `AshEdtf.Type` attribute stores the EDTF string together with the date range
it covers, so you can filter and sort on real dates while keeping the original
notation.

## Installation

With [Igniter](https://hexdocs.pm/igniter):

```sh
mix igniter.install ash_edtf
```

The installer

- registers the type under the short name `:edtf`,
- registers the AshEdtf expressions in `config :ash, :custom_expressions`,
- recompiles `ash` (both settings are compile-time config),
- adds `AshEdtf.AshPostgresExtension` to your repos and generates its migration.

Run the migration, and recompile `ash` once for your test build:

```sh
mix ash.migrate
MIX_ENV=test mix deps.compile ash --force
```

### Manual installation

Add the dependency:

```elixir
{:ash_edtf, "~> 0.1.0"}
```

Register the type and expressions in `config/config.exs`:

```elixir
config :ash,
  custom_types: [edtf: AshEdtf.Type],
  custom_expressions: [
    AshEdtf.Expressions.Overlaps,
    AshEdtf.Expressions.Day,
    AshEdtf.Expressions.Year,
    AshEdtf.Expressions.Month,
    AshEdtf.Expressions.Decade
  ]
```

Recompile `ash` (`mix deps.compile ash --force`), add the extension to your
repo and generate the migration:

```elixir
def installed_extensions do
  ["ash-functions", AshEdtf.AshPostgresExtension]
end
```

```sh
mix ash.codegen install_ash_edtf
mix ash.migrate
```

## Add an EDTF attribute

```elixir
defmodule MyApp.Archive.Letter do
  use Ash.Resource,
    domain: MyApp.Archive,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "letters"
    repo MyApp.Repo
  end

  actions do
    defaults [:read, :destroy, create: [:title, :date], update: [:title, :date]]
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, public?: true
    attribute :date, :edtf, public?: true
  end
end
```

```sh
mix ash.codegen add_letters
mix ash.migrate
```

## Store and read a value

Set the attribute with an EDTF string:

```elixir
letter =
  MyApp.Archive.Letter
  |> Ash.Changeset.for_create(:create, %{title: "To the publisher", date: "1850-06~"})
  |> Ash.create!()

letter.date
#=> %AshEdtf.Value{
#     value: "1850-06~",
#     lower: ~D[1850-06-01], lower_bound: :closed,
#     upper: ~D[1850-06-30], upper_bound: :closed
#   }

to_string(letter.date)
#=> "1850-06~"
```

`lower` and `upper` are the first and last day the date can refer to. For an
open-ended or unknown side the date is `nil` and the bound says why:

```elixir
Ash.Changeset.for_create(MyApp.Archive.Letter, :create, %{date: "1850/.."})
|> Ash.create!()
|> Map.get(:date)
#=> %AshEdtf.Value{value: "1850/..", lower: ~D[1850-01-01], upper: nil,
#     lower_bound: :closed, upper_bound: :open}
```

Invalid input is a normal validation error ("is not a valid EDTF date"), and
blank input is stored as `nil`. See [EDTF values](../topics/edtf-values.md)
for what each input form stores.

## Query

Filter and sort on the bounds, not on the string:

```elixir
require Ash.Query
require Ash.Sort

# letters that can fall into the 1850s, earliest first
MyApp.Archive.Letter
|> Ash.Query.filter(edtf_overlaps(date, ^~D[1850-01-01], ^~D[1859-12-31]))
|> Ash.Query.sort(Ash.Sort.expr_sort(date[:lower], AshEdtf.Day))
|> Ash.read!()
```

```elixir
# in a resource
calculations do
  calculate :decade, :integer, expr(edtf_decade(date[:lower]))
end
```

[Querying](../topics/querying.md) covers period search, comparisons with other
dates, calendar parts and aggregates.

## Show it in a form

The value renders as its EDTF string, so a text input works as is. Show the
reading next to it with `AshEdtf.Phoenix.humanize_field/1`:

```heex
<.input field={@form[:date]} type="text" label="Date (EDTF)" />
<p>{AshEdtf.Phoenix.humanize_field(@form[:date])}</p>
```

See [Forms](../topics/forms.md).

## Next steps

- [EDTF values](../topics/edtf-values.md) — what is stored for each input
- [Querying](../topics/querying.md)
- [Postgres](../topics/postgres.md) — SQL objects, indexing, raw SQL
- [Forms](../topics/forms.md)
