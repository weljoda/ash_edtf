# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## v0.1.0

Initial release.

### Features:

* `AshEdtf.Type`: EDTF strings stored with their derived bounds and bound kinds (`closed` / `open` /
  `unknown`) in an `edtf` Postgres composite.
* `AshEdtf.Day`: bounds as `Date`s in Elixir and day numbers in Postgres, for any year.
* `AshEdtf.AshPostgresExtension`: the composite type, `edtf_range/1` and calendar helper functions.
* Ash expressions `edtf_overlaps/3`, `edtf_day/1`, `edtf_year/1`, `edtf_month/1`, `edtf_decade/1`.
* `AshEdtf.Phoenix`: `humanize/1`, `humanize_field/1`, a headless `edtf_input/1` with an
  optional label and help for editors, and `examples/0` with common EDTF patterns.
* Igniter installer (`mix igniter.install ash_edtf`) and `mix ash_edtf.add_to_ash_postgres`.
* Usage rules for `usage_rules` (`usage-rules.md`, sub-rules `querying`, `postgres`, `forms`).
