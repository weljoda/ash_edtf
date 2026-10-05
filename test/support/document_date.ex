defmodule AshEdtf.Test.DocumentDate do
  @moduledoc false
  use Ash.Resource, domain: AshEdtf.Test.Domain, data_layer: AshPostgres.DataLayer

  postgres do
    table "document_dates"
    repo AshEdtf.Test.Repo

    references do
      reference :document, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:date, :document_id]
      upsert? true
      upsert_identity :unique_date
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :date, AshEdtf.Type do
      allow_nil? false
      public? true
    end
  end

  relationships do
    belongs_to :document, AshEdtf.Test.Document, allow_nil?: false, public?: true
  end

  identities do
    identity :unique_date, [:document_id, :date]
  end
end
