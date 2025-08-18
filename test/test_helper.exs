ExUnit.start()
Faker.start()

AshBackpex.TestRepo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(AshBackpex.TestRepo, :manual)
