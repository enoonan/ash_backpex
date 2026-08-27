defmodule Demo.Repo.Migrations.AddPostContentSections do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add(:sections, :map, null: false, default: "[]")
    end
  end
end
