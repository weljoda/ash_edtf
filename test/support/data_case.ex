defmodule AshEdtf.DataCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      import Ash.Expr
      import AshEdtf.DataCase

      alias AshEdtf.Test.{Document, DocumentDate, Repo}

      require Ash.Query
    end
  end

  setup tags do
    pid = Sandbox.start_owner!(AshEdtf.Test.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
    :ok
  end

  @doc "Creates a document."
  def create_document! do
    AshEdtf.Test.Document
    |> Ash.Changeset.for_create(:create, %{title: "doc"})
    |> Ash.create!()
  end

  @doc "Adds an EDTF date to a document."
  def add_date!(document, date) do
    AshEdtf.Test.DocumentDate
    |> Ash.Changeset.for_create(:create, %{document_id: document.id, date: date})
    |> Ash.create!()
  end

  @doc "Returns the document's dates matching `filter`, as EDTF strings sorted by value."
  def dates_matching(document, filter) do
    require Ash.Query

    AshEdtf.Test.DocumentDate
    |> Ash.Query.filter(document_id == ^document.id)
    |> Ash.Query.do_filter(filter)
    |> Ash.Query.sort(date: :asc)
    |> Ash.read!()
    |> Enum.map(&to_string(&1.date))
  end
end
