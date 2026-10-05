if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshEdtf.AddToAshPostgres do
    @shortdoc "Adds AshEdtf.AshPostgresExtension to the installed_extensions of your AshPostgres repos."
    @moduledoc """
    #{@shortdoc}

    Then generates the migration that installs the `edtf` type and its SQL
    functions.

    This is called automatically by `mix igniter.install ash_edtf` if
    `ash_postgres` is installed at the time. Run it yourself if you add
    `ash_postgres` *after* installing `ash_edtf`.
    """
    use Igniter.Mix.Task

    alias Igniter.Code.Common
    alias Igniter.Code.Function
    alias Igniter.Code.List, as: CodeList
    alias Igniter.Code.Module, as: CodeModule
    alias Igniter.Project.Module, as: ProjectModule

    @installed_extensions """
    def installed_extensions do
      # Add extensions here, and the migration generator will install them.
      [AshEdtf.AshPostgresExtension]
    end
    """

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{schema: [yes: :boolean]}
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      {igniter, repos} =
        ProjectModule.find_all_matching_modules(igniter, fn _module, zipper ->
          match?({:ok, _}, CodeModule.move_to_use(zipper, AshPostgres.Repo))
        end)

      case repos do
        [] ->
          Igniter.add_warning(
            igniter,
            "No `AshPostgres.Repo` found. Add `AshEdtf.AshPostgresExtension` to your repo's `installed_extensions/0` once you have one."
          )

        repos ->
          repos
          |> Enum.reduce(igniter, &add_extension/2)
          |> Ash.Igniter.codegen("install_ash_edtf")
      end
    end

    defp add_extension(repo, igniter) do
      ProjectModule.find_and_update_module!(igniter, repo, &update_repo(&1, repo))
    end

    defp update_repo(zipper, repo) do
      case Function.move_to_def(zipper, :installed_extensions, 0) do
        {:ok, zipper} -> append_extension(zipper, repo)
        _ -> {:ok, Common.add_code(zipper, @installed_extensions)}
      end
    end

    defp append_extension(zipper, repo) do
      with {:ok, zipper} <- Common.move_right(zipper, &CodeList.list?/1),
           {:ok, zipper} <- CodeList.append_new_to_list(zipper, AshEdtf.AshPostgresExtension) do
        {:ok, zipper}
      else
        _ ->
          {:error,
           "Couldn't add `AshEdtf.AshPostgresExtension` to #{inspect(repo)}.installed_extensions/0. " <>
             "Please add it by hand."}
      end
    end
  end
else
  defmodule Mix.Tasks.AshEdtf.AddToAshPostgres do
    @shortdoc "Adds AshEdtf.AshPostgresExtension to the installed_extensions of your AshPostgres repos."
    @moduledoc @shortdoc

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'ash_edtf.add_to_ash_postgres' requires igniter to be run.

      Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end
