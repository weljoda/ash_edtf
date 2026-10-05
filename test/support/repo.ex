defmodule AshEdtf.Test.Repo do
  @moduledoc false
  use AshPostgres.Repo, otp_app: :ash_edtf

  @impl true
  def installed_extensions, do: ["ash-functions", AshEdtf.AshPostgresExtension]

  @impl true
  def min_pg_version, do: %Version{major: 16, minor: 0, patch: 0}

  @impl true
  def prefer_transaction?, do: false
end
