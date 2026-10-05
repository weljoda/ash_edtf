{:ok, _} = AshEdtf.Test.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(AshEdtf.Test.Repo, :manual)

ExUnit.start()
