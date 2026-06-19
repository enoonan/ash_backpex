ExUnit.start(exclude: [:pending_implementation])
Faker.start()

AshBackpex.TestRepo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(AshBackpex.TestRepo, :manual)
