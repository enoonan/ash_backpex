# Fixtures for exercising AshBackpex.Adapter.delete_all/2 against a data layer
# that supports transactions. AshSqlite cannot transact, so these use Ash's
# in-memory Mnesia data layer instead.
defmodule AshBackpex.TransactionalTestDomain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource AshBackpex.TransactionalTestDomain.Entry
  end
end

defmodule AshBackpex.TransactionalTestDomain.Entry do
  @moduledoc false
  use Ash.Resource,
    domain: AshBackpex.TransactionalTestDomain,
    data_layer: Ash.DataLayer.Mnesia

  attributes do
    uuid_primary_key :id, writable?: true

    attribute :name, :string do
      allow_nil? false
      public? true
    end
  end

  actions do
    defaults [:read, create: [:name]]

    destroy :destroy do
      primary? true
      require_atomic? false

      # Fails after the data layer has already deleted the record, so the
      # deletion is only undone if the surrounding transaction rolls back.
      change after_action(fn _changeset, record, _context ->
               if record.name == "blocked" do
                 {:error,
                  Ash.Error.Changes.InvalidChanges.exception(
                    fields: [:name],
                    message: "cannot be deleted"
                  )}
               else
                 {:ok, record}
               end
             end)
    end
  end
end

# Minimal LiveResource stand-in: delete_all/2 only reads adapter configuration.
defmodule TestTransactionalEntryLive do
  @moduledoc false

  def config(:adapter_config),
    do: [resource: AshBackpex.TransactionalTestDomain.Entry, destroy_action: :destroy]

  def config(:resource), do: AshBackpex.TransactionalTestDomain.Entry
  def config(:primary_key), do: :id
end
