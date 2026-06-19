defmodule DemoWeb.CommentLive do
  use AshBackpex.LiveResource

  backpex do
    resource(Demo.Blog.Comment)
    layout(&DemoWeb.Layouts.admin/1)
    singular_name("Comment")
    plural_name("Comments")
    init_order(%{by: :inserted_at, direction: :desc})
    per_page_default(10)
    load([:post, :author])

    panels(
      comment: "Comment",
      moderation: "Moderation"
    )

    filters do
      filter :approved

      filter :sentiment do
        prompt("Any sentiment")
      end

      filter :inserted_at do
        label("Submitted")
        type(:datetime)
      end
    end

    item_actions do
      strip_default([:delete])
    end

    fields do
      field :post do
        display_field(:title)
        live_resource(DemoWeb.PostLive)
        panel(:comment)
      end

      field :author do
        display_field(:name)
        live_resource(DemoWeb.AuthorLive)
        panel(:comment)
      end

      field :body do
        module(Backpex.Fields.Textarea)
        searchable(true)
        panel(:comment)
        rows(4)
      end

      field :sentiment do
        panel(:moderation)
      end

      field :approved do
        panel(:moderation)
        index_editable(true)
      end

      field :inserted_at do
        except([:new, :edit])
        label("Submitted")
        format("%b %d, %Y %H:%M")
      end

      field :updated_at do
        only([:show])
        format("%b %d, %Y %H:%M")
      end
    end
  end
end
