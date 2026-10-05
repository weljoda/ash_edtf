defmodule Mix.Tasks.AshEdtf.InstallTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  alias Igniter.Project.Deps

  @repo """
  defmodule Test.Repo do
    use AshPostgres.Repo, otp_app: :test

    def installed_extensions do
      ["ash-functions"]
    end
  end
  """

  @repo_without_extensions """
  defmodule Test.Repo do
    use AshPostgres.Repo, otp_app: :test
  end
  """

  defp project_with_ash_postgres(repo_source) do
    test_project(files: %{"lib/test/repo.ex" => repo_source})
    |> Deps.add_dep({:ash_postgres, "~> 2.0"})
    |> apply_igniter!()
  end

  describe "ash_edtf.install" do
    test "registers the :edtf short name and the custom expressions" do
      test_project()
      |> Igniter.compose_task("ash_edtf.install", [])
      |> assert_creates("config/config.exs", """
      import Config

      config :ash,
        custom_types: [edtf: AshEdtf.Type],
        custom_expressions: [
          AshEdtf.Expressions.Overlaps,
          AshEdtf.Expressions.Day,
          AshEdtf.Expressions.Year,
          AshEdtf.Expressions.Month,
          AshEdtf.Expressions.Decade
        ]
      """)
      |> assert_has_task("deps.compile", ["ash", "--force"])
      |> assert_has_notice(&String.contains?(&1, "MIX_ENV=test mix deps.compile ash --force"))
    end

    test "appends to existing custom expressions without duplicating" do
      test_project(
        files: %{
          "config/config.exs" => """
          import Config

          config :ash, custom_expressions: [MyApp.Expressions.Other, AshEdtf.Expressions.Overlaps]
          """
        }
      )
      |> Igniter.compose_task("ash_edtf.install", [])
      |> apply_igniter!()
      |> assert_content_equals("config/config.exs", """
      import Config

      config :ash,
        custom_expressions: [
          MyApp.Expressions.Other,
          AshEdtf.Expressions.Overlaps,
          AshEdtf.Expressions.Day,
          AshEdtf.Expressions.Year,
          AshEdtf.Expressions.Month,
          AshEdtf.Expressions.Decade
        ],
        custom_types: [edtf: AshEdtf.Type]
      """)
    end

    test "is idempotent and doesn't recompile ash when nothing changed" do
      igniter =
        test_project()
        |> Igniter.compose_task("ash_edtf.install", [])
        |> apply_igniter!()
        |> Igniter.compose_task("ash_edtf.install", [])

      assert_unchanged(igniter, "config/config.exs")
      refute Enum.any?(igniter.tasks, &match?({"deps.compile", _}, &1))
    end

    test "skips the Postgres step without ash_postgres" do
      test_project(files: %{"lib/test/repo.ex" => @repo})
      |> Igniter.compose_task("ash_edtf.install", [])
      |> assert_unchanged("lib/test/repo.ex")
    end

    test "adds the Postgres extension when ash_postgres is installed" do
      @repo
      |> project_with_ash_postgres()
      |> Igniter.compose_task("ash_edtf.install", [])
      |> assert_has_patch("lib/test/repo.ex", """
      - |    ["ash-functions"]
      + |    ["ash-functions", AshEdtf.AshPostgresExtension]
      """)
      |> then(fn igniter ->
        assert Enum.map(igniter.tasks, &elem(&1, 0)) == ["deps.compile", "ash.codegen"]
        igniter
      end)
    end
  end

  describe "ash_edtf.add_to_ash_postgres" do
    test "appends to an existing installed_extensions/0 and queues codegen" do
      @repo
      |> project_with_ash_postgres()
      |> Igniter.compose_task("ash_edtf.add_to_ash_postgres", [])
      |> assert_has_patch("lib/test/repo.ex", """
      + |    ["ash-functions", AshEdtf.AshPostgresExtension]
      """)
      |> assert_has_task("ash.codegen", ["install_ash_edtf"])
    end

    test "creates installed_extensions/0 when the repo has none" do
      @repo_without_extensions
      |> project_with_ash_postgres()
      |> Igniter.compose_task("ash_edtf.add_to_ash_postgres", [])
      |> assert_has_patch("lib/test/repo.ex", """
      + |  def installed_extensions do
      + |    # Add extensions here, and the migration generator will install them.
      + |    [AshEdtf.AshPostgresExtension]
      + |  end
      """)
    end

    test "is idempotent" do
      @repo
      |> project_with_ash_postgres()
      |> Igniter.compose_task("ash_edtf.add_to_ash_postgres", [])
      |> apply_igniter!()
      |> Igniter.compose_task("ash_edtf.add_to_ash_postgres", [])
      |> assert_unchanged("lib/test/repo.ex")
    end

    test "warns when there is no repo" do
      test_project()
      |> Igniter.compose_task("ash_edtf.add_to_ash_postgres", [])
      |> assert_has_warning(&String.contains?(&1, "No `AshPostgres.Repo` found"))
    end
  end
end
