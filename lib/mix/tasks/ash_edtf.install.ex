if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshEdtf.Install do
    @example "mix igniter.install ash_edtf"
    @shortdoc "Installs AshEdtf. Should be run with `#{@example}`"
    @moduledoc """
    #{@shortdoc}

    - Registers `AshEdtf.Type` under the short name `:edtf`
      (`config :ash, :custom_types`), so attributes can be declared as
      `attribute :date, :edtf`.
    - Adds the AshEdtf expressions to `config :ash, :custom_expressions`.
    - Recompiles `ash` when that config changed (it is read at compile time).
    - If `ash_postgres` is installed, runs `mix ash_edtf.add_to_ash_postgres`,
      which adds `AshEdtf.AshPostgresExtension` to every repo and generates the
      migration.

    ## Example

    ```bash
    #{@example}
    ```
    """
    use Igniter.Mix.Task

    alias Igniter.Project.Config
    alias Igniter.Project.Deps

    @expressions [
      AshEdtf.Expressions.Overlaps,
      AshEdtf.Expressions.Day,
      AshEdtf.Expressions.Year,
      AshEdtf.Expressions.Month,
      AshEdtf.Expressions.Decade
    ]

    @config_path "config/config.exs"

    @notice """
    AshEdtf changed `config :ash, :custom_types` and `:custom_expressions`.
    Both are read when `ash` is compiled; the installer recompiled it for this
    environment. Do the same for your test build:

        MIX_ENV=test mix deps.compile ash --force
    """

    @doc "The expression modules the installer registers."
    def expressions, do: @expressions

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{example: @example, schema: [yes: :boolean]}
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      config_before = config_content(igniter)

      igniter
      |> Config.configure("config.exs", :ash, [:custom_types, :edtf], AshEdtf.Type)
      |> Config.configure("config.exs", :ash, [:custom_expressions], @expressions, updater: &append_expressions/1)
      |> recompile_ash_if_changed(config_before)
      |> maybe_add_to_ash_postgres()
    end

    # `ash` reads both settings at compile time, so a stale build fails every
    # later task (including the codegen queued below) with a compile-env
    # mismatch. The recompile is queued first so it runs before the codegen.
    defp recompile_ash_if_changed(igniter, config_before) do
      if config_content(igniter) == config_before do
        igniter
      else
        igniter
        |> Igniter.add_task("deps.compile", ["ash", "--force"])
        |> Igniter.add_notice(@notice)
      end
    end

    defp config_content(igniter) do
      case Rewrite.source(igniter.rewrite, @config_path) do
        {:ok, source} -> Rewrite.Source.get(source, :content)
        _ -> nil
      end
    end

    defp append_expressions(zipper) do
      Enum.reduce_while(@expressions, {:ok, zipper}, fn module, {:ok, zipper} ->
        case Igniter.Code.List.append_new_to_list(zipper, module) do
          {:ok, zipper} -> {:cont, {:ok, zipper}}
          :error -> {:halt, :error}
        end
      end)
    end

    defp maybe_add_to_ash_postgres(igniter) do
      if Deps.has_dep?(igniter, :ash_postgres) do
        Igniter.compose_task(igniter, "ash_edtf.add_to_ash_postgres", igniter.args.argv)
      else
        igniter
      end
    end
  end
else
  defmodule Mix.Tasks.AshEdtf.Install do
    @shortdoc "Installs AshEdtf. Should be run with `mix igniter.install ash_edtf`"
    @moduledoc @shortdoc

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'ash_edtf.install' requires igniter to be run.

      Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end
