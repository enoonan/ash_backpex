defmodule Demo.Blog.Post do
  use Ash.Resource,
    domain: Demo.Blog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "posts"
    repo Demo.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :content, :string do
      allow_nil? true
      public? true
    end

    attribute :rating, :integer do
      default 5
      public? true
      constraints [min: 1, max: 5]
    end

    attribute :published, :boolean do
      default false
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  calculations do
    calculate :word_count, :integer do
      public? true

      calculation fn records, _context ->
        Enum.map(records, fn record ->
          case record.content do
            nil -> 0
            content -> content |> String.split(~r/\s+/) |> Enum.reject(&(&1 == "")) |> length()
          end
        end)
      end
    end
  end

  actions do
    default_accept [:title, :content, :published, :rating]
    defaults [:create, :read, :update, :destroy]
  end
end
