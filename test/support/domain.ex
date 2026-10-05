defmodule AshEdtf.Test.Domain do
  @moduledoc false
  use Ash.Domain

  resources do
    resource AshEdtf.Test.Document
    resource AshEdtf.Test.DocumentDate
    resource AshEdtf.Test.EtsEvent
  end
end
