# Changelog

## Unreleased

Initial version, extracted from the valep_ex project.

- `AshEdtf.Type`: EDTF strings stored with their derived bounds and bound kinds (`closed` / `open` /
  `unknown`) in an `edtf` Postgres composite.
- `AshEdtf.Day`: bounds as day numbers in Postgres, `Date`s in Elixir; no 4713 BC limit.
- `AshEdtf.AshPostgresExtension`: the composite type, `edtf_range/1` and calendar helper functions.
- Ash expressions `edtf_overlaps/3`, `edtf_day/1`, `edtf_year/1`, `edtf_month/1`, `edtf_decade/1`.
- `AshEdtf.Phoenix`: `humanize/1`, `humanize_field/1` and a headless `edtf_input/1`.
