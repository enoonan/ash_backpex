defmodule AshBackpex.TestRepo.Migrations.CreateReadOnlyEntries do
  @moduledoc """
  Creates the read_only_entries table for testing can?/3 with missing actions.
  """

  use Ecto.Migration

  def up do
    create table(:read_only_entries, primary_key: false) do
      add :id, :text, null: false, primary_key: true
      add :name, :text, null: false
      add :inserted_at, :utc_datetime_usec, null: false, default: fragment("CURRENT_TIMESTAMP")
    end
  end

  def down do
    drop table(:read_only_entries)
  end
end
