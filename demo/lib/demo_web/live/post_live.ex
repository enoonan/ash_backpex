defmodule DemoWeb.PostLive do
  use AshBackpex.LiveResource

  import Phoenix.Component, only: [sigil_H: 2]

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

    load([
      :author,
      :comments,
      :topic_tags,
      :audience_tags,
      :word_count,
      :comment_count,
      gallery: [:url, :blob]
    ])

    panels(
      content: "Content",
      publishing: "Publishing",
      relationships: "Relationships",
      composition: "Content composition"
    )

    # Filters demonstrating auto-derivation from Ash attribute types
    filters do
      # Boolean filter - auto-derived from :boolean attribute
      filter :published

      # MultiSelect filter - explicit module, options derived from :atom one_of constraints
      filter :status do
        module(AshBackpex.Filters.MultiSelect)
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
        typeahead(true)
        typeahead_limit(10)
        debounce(300)
        index_editable(true)
        prompt("Choose an author...")
      end

      field :topic_tags do
        label("Topic Tags")
        display_field(:name)
        live_resource(DemoWeb.TagLive)
        panel(:relationships)
        prompt("Choose topic tags...")
      end

      field :audience_tags do
        label("Audience Tags")
        display_field(:name)
        live_resource(DemoWeb.TagLive)
        panel(:relationships)
        prompt("Choose audience tags...")
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

      # An AshStorage has_many_attached. Backpex consumes the uploads after the
      # post is saved; the callbacks below attach and purge them with AshStorage.
      field :gallery, Backpex.Fields.Upload do
        panel(:content)
        accept(~w(.jpg .jpeg .png .gif .webp))
        max_entries(6)
        max_file_size(5_000_000)
        render(&__MODULE__.render_gallery/1)
        list_existing_files(&__MODULE__.list_gallery_files/1)
        file_label(&__MODULE__.gallery_file_label/1)
        put_upload_change(&__MODULE__.put_gallery_change/6)
        consume_upload(&__MODULE__.consume_gallery_upload/4)
        remove_uploads(&__MODULE__.remove_gallery_uploads/3)
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
        only([:index])
        label("Comments")
      end

      field :comments do
        module(Backpex.Fields.InlineCRUD)
        except([:index])
        live_resource(DemoWeb.CommentLive)
        panel(:relationships)

        child_fields do
          field :body, Backpex.Fields.Textarea do
            label("Body")
            rows(3)
          end

          field :author do
            label("Author")
            display_field(:name)
            typeahead(true)
            typeahead_limit(10)
            prompt("Choose an author")
            class("w-56")
          end

          field :sentiment do
            label("Sentiment")
            options(Positive: :positive, Neutral: :neutral, Critical: :critical)
            class("w-40")
          end

          field :approved do
            label("Approved")
            class("w-28")
          end
        end
      end

      field :sections do
        module(Backpex.Fields.InlineCRUD)
        except([:index])
        panel(:composition)

        child_fields do
          field(:title)

          field :columns do
            module(Backpex.Fields.InlineCRUD)

            child_fields do
              field(:heading)

              field :target do
                module(AshBackpex.Fields.Embedded)

                child_fields do
                  field(:kind)
                  field(:path)
                end
              end
            end
          end
        end
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

  def render_gallery(assigns) do
    ~H"""
    <div class="flex flex-wrap gap-2">
      <img
        :for={image <- List.wrap(@value)}
        src={image.url}
        alt={image.blob.filename}
        class="h-12 w-12 rounded object-cover"
      />
      <span :if={List.wrap(@value) == []}>—</span>
    </div>
    """
  end

  # Backpex identifies files by a string. "<blob id>/<filename>" carries the blob
  # id for AshStorage and the filename for the form's label.
  def list_gallery_files(%{gallery: images}) when is_list(images),
    do: Enum.map(images, &"#{&1.blob_id}/#{&1.blob.filename}")

  def list_gallery_files(_item), do: []

  def gallery_file_label(file), do: file |> String.split("/", parts: 2) |> List.last()

  # Attachments are not inputs of the Ash action, so the params stay as they are.
  def put_gallery_change(_socket, params, _item, _uploaded, _removed, _action), do: params

  def consume_gallery_upload(_socket, post, %{path: path}, entry) do
    # Pass a file struct: AshStorage stores a binary argument as the file's bytes.
    {:ok, _result} =
      AshStorage.Operations.attach(post, :gallery, Ash.Type.File.from_path(path),
        filename: entry.client_name,
        content_type: entry.client_type
      )

    {:ok, entry.client_name}
  end

  def remove_gallery_uploads(_socket, post, removed_files) do
    for file <- removed_files do
      [blob_id | _filename] = String.split(file, "/", parts: 2)
      {:ok, _purged} = AshStorage.Operations.purge(post, :gallery, blob_id: blob_id)
    end
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
