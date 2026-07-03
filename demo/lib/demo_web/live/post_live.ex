defmodule DemoWeb.PostLive do
  use AshBackpex.LiveResource

  backpex do
    resource(Demo.Blog.Post)
    layout(&DemoWeb.Layouts.admin/1)
    singular_name("Article")
    plural_name("Articles")
    init_order(%{by: :inserted_at, direction: :desc})
    per_page_default(5)
    per_page_options([5, 10, 25])
    fluid?(true)
    save_and_continue_button?(true)
    create_action(:admin_create)
    update_action(:admin_update)
    create_changeset(&DemoWeb.PostLive.admin_create_changeset/3)
    update_changeset(&DemoWeb.PostLive.admin_update_changeset/3)
    load([:author, :comments, :tags, :word_count, :comment_count])

    panels(
      content: "Content",
      publishing: "Publishing",
      relationships: "Relationships"
    )

    # Filters demonstrating auto-derivation from Ash attribute types
    filters do
      # Boolean filter - auto-derived from :boolean attribute
      filter :published

      # Select filter - auto-derived from :atom one_of constraints
      filter :status do
        prompt("Any status")
      end

      # Range filter - auto-derived from :integer attribute
      filter :rating

      # Range filter - auto-derived from :utc_datetime attribute
      filter :inserted_at do
        label("Created Date")
      end
    end

    item_actions do
      action :publish, DemoWeb.ItemActions.PublishPost, only: [:row, :index, :show]
    end

    fields do
      field(:title) do
        searchable(true)
        panel(:content)
        placeholder("A concise title")
      end

      field :slug do
        panel(:content)
        placeholder("a-concise-title")
      end

      field :author do
        display_field(:name)
        live_resource(DemoWeb.AuthorLive)
        panel(:relationships)
      end

      field :tags do
        display_field(:name)
        live_resource(DemoWeb.TagLive)
        panel(:relationships)
        prompt("Choose tags...")
      end

      field :content do
        module(Backpex.Fields.Textarea)
        searchable(true)
        panel(:content)
        rows(10)
        placeholder("Write the article body...")
      end

      field :excerpt do
        module(Backpex.Fields.Textarea)
        except([:index])
        panel(:content)
        rows(3)
      end

      field :status do
        panel(:publishing)
      end

      field :published do
        panel(:publishing)
        index_editable(true)
      end

      field :published_on do
        panel(:publishing)
        format("%b %d, %Y")
      end

      field :featured do
        panel(:publishing)
        index_editable(true)
      end

      field :rating do
        panel(:publishing)
      end

      field :word_count do
        except([:new, :edit])
      end

      field :comment_count do
        except([:new, :edit])
        label("Comments")
      end

      field :comments do
        except([:new, :edit])
        display_field(:body)
        live_resource(DemoWeb.CommentLive)
      end

      field :inserted_at do
        label("Created At")
        except([:new, :edit])
        format("%b %d, %Y %H:%M")
      end

      field :updated_at do
        label("Updated At")
        except([:new, :edit])
        format("%b %d, %Y %H:%M")
      end
    end
  end

  def admin_create_changeset(item, params, metadata) do
    assigns = Keyword.get(metadata, :assigns, %{})

    item.__struct__
    |> Ash.Changeset.for_create(:admin_create, normalize_params(params),
      actor: Map.get(assigns, :current_user)
    )
  end

  def admin_update_changeset(item, params, metadata) do
    assigns = Keyword.get(metadata, :assigns, %{})

    item
    |> Ash.Changeset.for_update(:admin_update, normalize_params(params),
      actor: Map.get(assigns, :current_user)
    )
  end

  defp normalize_params(params) do
    params
    |> maybe_put_slug()
    |> maybe_sync_published_fields()
  end

  defp maybe_put_slug(%{"slug" => slug} = params) when slug not in [nil, ""], do: params

  defp maybe_put_slug(%{"title" => title} = params) when is_binary(title) do
    Map.put(params, "slug", slugify(title))
  end

  defp maybe_put_slug(params), do: params

  defp maybe_sync_published_fields(%{"status" => "published"} = params) do
    params
    |> Map.put("published", "true")
    |> Map.put_new("published_on", Date.utc_today() |> Date.to_iso8601())
  end

  defp maybe_sync_published_fields(%{status: :published} = params) do
    params
    |> Map.put(:published, true)
    |> Map.put_new(:published_on, Date.utc_today())
  end

  defp maybe_sync_published_fields(params), do: params

  defp slugify(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
  end
end
