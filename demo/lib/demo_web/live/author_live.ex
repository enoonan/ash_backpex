defmodule DemoWeb.AuthorLive do
  use AshBackpex.LiveResource

  backpex do
    resource(Demo.Blog.Author)
    layout(&DemoWeb.Layouts.admin/1)
    singular_name("Author")
    plural_name("Authors")
    init_order(%{by: :name, direction: :asc})
    per_page_default(10)
    per_page_options([5, 10, 25])
    load([:posts])

    panels(
      profile: "Profile",
      publishing: "Publishing"
    )

    filters do
      filter :active

      filter :role do
        prompt("Any role")
      end
    end

    fields do
      field :name do
        searchable(true)
        panel(:profile)
        placeholder("Ada Lovelace")
      end

      field :email do
        searchable(true)
        panel(:profile)
        placeholder("author@example.com")
      end

      field :bio do
        module(Backpex.Fields.Textarea)
        panel(:profile)
        rows(5)
      end

      field :role do
        panel(:publishing)
      end

      field :active do
        panel(:publishing)
        index_editable(true)
      end

      field :joined_on do
        panel(:publishing)
        format("%b %d, %Y")
      end

      field :posts do
        except([:new, :edit])
        display_field(:title)
        live_resource(DemoWeb.PostLive)
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
