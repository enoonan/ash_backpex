defmodule DemoWeb.PostLive do
  use AshBackpex.LiveResource

  backpex do
    resource(Demo.Blog.Post)
    layout(&DemoWeb.Layouts.admin/1)
    init_order(%{by: :inserted_at, direction: :desc})
    load([:word_count])

    # Filters demonstrating auto-derivation from Ash attribute types
    filters do
      # Boolean filter - auto-derived from :boolean attribute
      filter :published

      # Range filter - auto-derived from :integer attribute
      filter :rating

      # Range filter - auto-derived from :utc_datetime attribute
      filter :inserted_at do
        label "Created Date"
      end
    end

    fields do
      field(:title) do
        searchable(true)
      end

      field :content do
        module(Backpex.Fields.Textarea)
        searchable(true)
      end

      field(:published)

      field :rating

      field :word_count do
        except([:new, :edit])
      end

      field :inserted_at do
        label("Created At")
        except([:new, :edit])
      end

      field :updated_at do
        label("Updated At")
        except([:new, :edit])
      end
    end
  end
end
