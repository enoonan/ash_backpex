defmodule DemoWeb.TagLive do
  use AshBackpex.LiveResource

  backpex do
    resource(Demo.Blog.Tag)
    layout(&DemoWeb.Layouts.admin/1)
    singular_name("Tag")
    plural_name("Tags")
    init_order(%{by: :name, direction: :asc})
    per_page_default(10)
    load([:posts])

    panels(
      details: "Details",
      relationships: "Relationships"
    )

    fields do
      field :name do
        searchable(true)
        panel(:details)
        placeholder("Ash")
      end

      field :slug do
        panel(:details)
        placeholder("ash")
      end

      field :description do
        module(Backpex.Fields.Textarea)
        panel(:details)
        rows(4)
      end

      field :posts do
        except([:new, :edit])
        display_field(:title)
        live_resource(DemoWeb.PostLive)
        panel(:relationships)
      end

      field :inserted_at do
        only([:show])
        format("%b %d, %Y")
      end

      field :updated_at do
        only([:show])
        format("%b %d, %Y")
      end
    end
  end
end
