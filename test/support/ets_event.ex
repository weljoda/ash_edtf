defmodule AshEdtf.Test.EtsEvent do
  @moduledoc false
  use Ash.Resource, domain: AshEdtf.Test.Domain, data_layer: Ash.DataLayer.Ets

  ets do
    private? true
  end

  actions do
    defaults [:read, create: [:date]]
  end

  attributes do
    uuid_primary_key :id
    attribute :date, AshEdtf.Type, public?: true
  end
end
