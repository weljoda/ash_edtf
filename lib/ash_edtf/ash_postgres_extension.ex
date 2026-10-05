if Code.ensure_loaded?(AshPostgres.CustomExtension) do
  defmodule AshEdtf.AshPostgresExtension do
    @moduledoc """
    Installs the Postgres objects `AshEdtf.Type` is stored in:

    - `edtf_bound` — a `text` domain restricted to `closed`/`open`/`unknown`.
    - `edtf` — the composite `(value text, lower bigint, upper bigint,
      lower_bound edtf_bound, upper_bound edtf_bound)`. Bounds are day
      numbers (`Date.to_gregorian_days/1`, day 0 = 0000-01-01), so any EDTF
      year fits; see `AshEdtf.Day`.
    - `edtf_range(edtf)` — an immutable function returning the covered
      `int8range` of day numbers (inclusive; `open` and `unknown` sides are
      unbounded, `NULL` input gives `NULL`). It is what `edtf_overlaps/3`
      queries and what an optional GiST index should be built on; see
      `AshEdtf.Type`.
    - `edtf_date_to_day(date)` / `edtf_day_to_date(bigint)` — convert between
      Postgres dates and day numbers. The latter errors outside the Postgres
      `date` range (4713 BC – 5874897 AD).
    - `edtf_day_year(bigint)`, `edtf_day_month(bigint)` (1–12) and
      `edtf_day_decade(bigint)` (first year of the decade: 1850 for
      1850–1859, -1850 for -1850 to -1841) — calendar parts of a day number
      for any year, instead of `extract(...)`. Years are astronomical
      (0 = 1 BC), as in Elixir. They build on `edtf_day_parts(bigint)`, which
      returns `(year, month, day_of_month)`. Ash expressions:
      `edtf_year/1`, `edtf_month/1`, `edtf_decade/1`.

    Add it to the repo, then run `mix ash.codegen`:

    ```elixir
    def installed_extensions do
      [..., AshEdtf.AshPostgresExtension]
    end
    ```
    """
    use AshPostgres.CustomExtension, name: :ash_edtf, latest_version: 1

    # Day number of 2000-01-01 (`Date.to_gregorian_days(~D[2000-01-01])`).
    @epoch_2000 730_485

    @create_bound """
    CREATE DOMAIN edtf_bound AS text
      CHECK (VALUE IN ('closed', 'open', 'unknown'))
    """

    @create_type """
    CREATE TYPE edtf AS (
      value text,
      lower bigint,
      upper bigint,
      lower_bound edtf_bound,
      upper_bound edtf_bound
    )
    """

    @create_range_function """
    CREATE OR REPLACE FUNCTION edtf_range(value edtf)
    RETURNS int8range
    LANGUAGE sql
    IMMUTABLE STRICT PARALLEL SAFE
    AS $$ SELECT int8range((value).lower, (value).upper, '[]') $$
    """

    @create_date_to_day_function """
    CREATE OR REPLACE FUNCTION edtf_date_to_day(value date)
    RETURNS bigint
    LANGUAGE sql
    IMMUTABLE STRICT PARALLEL SAFE
    AS $$ SELECT (value - DATE '2000-01-01')::bigint + #{@epoch_2000} $$
    """

    @create_day_to_date_function """
    CREATE OR REPLACE FUNCTION edtf_day_to_date(day bigint)
    RETURNS date
    LANGUAGE sql
    IMMUTABLE STRICT PARALLEL SAFE
    AS $$ SELECT DATE '2000-01-01' + (day - #{@epoch_2000})::integer $$
    """

    # Howard Hinnant's civil_from_days, shifted from day 0 = 0000-01-01 to
    # its 0000-03-01 era origin (60 days later). Floor division keeps it
    # correct for negative years.
    @create_day_parts_function """
    CREATE OR REPLACE FUNCTION edtf_day_parts(
      day bigint,
      OUT year bigint,
      OUT month integer,
      OUT day_of_month integer
    )
    LANGUAGE sql
    IMMUTABLE STRICT PARALLEL SAFE
    AS $$
      WITH era AS (
        SELECT day - 60 AS z, floor((day - 60)::numeric / 146097)::bigint AS era
      ), doe AS (
        SELECT era, z - era * 146097 AS doe FROM era
      ), yoe AS (
        SELECT era, doe, (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365 AS yoe FROM doe
      ), doy AS (
        SELECT era, yoe, doe - (365 * yoe + yoe / 4 - yoe / 100) AS doy FROM yoe
      ), mp AS (
        SELECT era, yoe, doy, (5 * doy + 2) / 153 AS mp FROM doy
      )
      SELECT
        yoe + era * 400 + CASE WHEN mp >= 10 THEN 1 ELSE 0 END,
        (CASE WHEN mp < 10 THEN mp + 3 ELSE mp - 9 END)::integer,
        (doy - (153 * mp + 2) / 5 + 1)::integer
      FROM mp
    $$
    """

    @create_day_year_function """
    CREATE OR REPLACE FUNCTION edtf_day_year(day bigint)
    RETURNS bigint
    LANGUAGE sql
    IMMUTABLE STRICT PARALLEL SAFE
    AS $$ SELECT (edtf_day_parts(day)).year $$
    """

    @create_day_month_function """
    CREATE OR REPLACE FUNCTION edtf_day_month(day bigint)
    RETURNS integer
    LANGUAGE sql
    IMMUTABLE STRICT PARALLEL SAFE
    AS $$ SELECT (edtf_day_parts(day)).month $$
    """

    @create_day_decade_function """
    CREATE OR REPLACE FUNCTION edtf_day_decade(day bigint)
    RETURNS bigint
    LANGUAGE sql
    IMMUTABLE STRICT PARALLEL SAFE
    AS $$ SELECT floor((edtf_day_parts(day)).year::numeric / 10)::bigint * 10 $$
    """

    @impl true
    def install(0) do
      execute_each([
        @create_bound,
        @create_type,
        @create_range_function,
        @create_date_to_day_function,
        @create_day_to_date_function,
        @create_day_parts_function,
        @create_day_year_function,
        @create_day_month_function,
        @create_day_decade_function
      ])
    end

    def install(_version), do: ""

    @impl true
    def uninstall(_version) do
      execute_each([
        "DROP FUNCTION IF EXISTS edtf_day_decade(bigint)",
        "DROP FUNCTION IF EXISTS edtf_day_month(bigint)",
        "DROP FUNCTION IF EXISTS edtf_day_year(bigint)",
        "DROP FUNCTION IF EXISTS edtf_day_parts(bigint)",
        "DROP FUNCTION IF EXISTS edtf_day_to_date(bigint)",
        "DROP FUNCTION IF EXISTS edtf_date_to_day(date)",
        "DROP FUNCTION IF EXISTS edtf_range(edtf)",
        "DROP TYPE IF EXISTS edtf",
        "DROP DOMAIN IF EXISTS edtf_bound"
      ])
    end

    defp execute_each(statements) do
      Enum.map_join(statements, "\n", &"execute(#{inspect(String.trim(&1))})")
    end
  end
end
