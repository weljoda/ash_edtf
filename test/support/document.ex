defmodule AshEdtf.Test.Document do
  @moduledoc false
  use Ash.Resource, domain: AshEdtf.Test.Domain, data_layer: AshPostgres.DataLayer

  postgres do
    table "documents"
    repo AshEdtf.Test.Repo
  end

  actions do
    defaults [:read, :destroy, create: [:title]]
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, public?: true
  end

  relationships do
    has_many :dates, AshEdtf.Test.DocumentDate
  end

  calculations do
    calculate :earliest_date,
              AshEdtf.Day,
              expr(min(dates, expr: date[:lower], expr_type: AshEdtf.Day))
  end
end
