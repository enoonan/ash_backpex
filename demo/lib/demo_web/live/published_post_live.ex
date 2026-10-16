defmodule DemoWeb.PublishedPostLive do
  @moduledoc """
  Published articles only. `read_action :published_only` makes the index, show
  page and count read through that action's filter, so drafts are not listed
  and their show pages return 404. Creating and editing still use the primary
  create and update actions.
  """

  use AshBackpex.LiveResource

  backpex do
    resource(Demo.Blog.Post)
    layout(&DemoWeb.Layouts.admin/1)
    singular_name("Published Article")
    plural_name("Published Articles")
    read_action(:published_only)
    init_order(%{by: :inserted_at, direction: :desc})
    per_page_default(2)
    per_page_options([2, 5, 10])
    load([:author])

    fields do
      field :title do
        searchable(true)
      end

      field :author do
        display_field(:name)
        live_resource(DemoWeb.AuthorLive)
      end

      field(:status)
      field(:published)
      field(:published_on)
    end
  end
end
