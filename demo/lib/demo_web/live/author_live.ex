defmodule DemoWeb.AuthorLive do
  use AshBackpex.LiveResource

  import Phoenix.Component, only: [sigil_H: 2]

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

      field :avatar, Backpex.Fields.Upload do
        panel(:profile)
        accept(~w(.jpg .jpeg .png .gif .webp))
        max_entries(1)
        max_file_size(2_000_000)
        render(&__MODULE__.render_avatar/1)
        list_existing_files(&__MODULE__.list_existing_files/1)
        put_upload_change(&__MODULE__.put_upload_change/6)
        consume_upload(&__MODULE__.consume_upload/4)
        remove_uploads(&__MODULE__.remove_uploads/3)
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

  # Avatars are stored on local disk in priv/uploads and served at /uploads by
  # DemoWeb.Endpoint. The `avatar` attribute stores the file name.
  def upload_dir, do: Application.app_dir(:demo, "priv/uploads")

  def render_avatar(assigns) do
    ~H"""
    <div>
      <img
        :if={@value}
        src={"/uploads/#{@value}"}
        alt="Avatar"
        class="h-10 w-10 rounded-full object-cover"
      />
      <span :if={!@value}>—</span>
    </div>
    """
  end

  def list_existing_files(%{avatar: avatar}) when is_binary(avatar), do: [avatar]
  def list_existing_files(_item), do: []

  def put_upload_change(_socket, params, item, uploaded_entries, removed_entries, action) do
    existing_files = list_existing_files(item) -- removed_entries

    new_entries =
      case action do
        :validate -> elem(uploaded_entries, 1)
        :insert -> elem(uploaded_entries, 0)
      end

    files = existing_files ++ Enum.map(new_entries, &file_name/1)

    # max_entries is 1, so the newest file replaces an existing one.
    Map.put(params, "avatar", List.last(files))
  end

  def consume_upload(_socket, _item, %{path: path}, entry) do
    File.mkdir_p!(upload_dir())
    File.cp!(path, Path.join(upload_dir(), file_name(entry)))

    {:ok, file_name(entry)}
  end

  def remove_uploads(_socket, _item, removed_entries) do
    for file <- removed_entries, do: delete_file(file)
  end

  @impl Backpex.LiveResource
  def on_item_deleted(socket, item) do
    for file <- list_existing_files(item), do: delete_file(file)
    socket
  end

  defp file_name(entry), do: entry.uuid <> Path.extname(entry.client_name)

  defp delete_file(file), do: File.rm(Path.join(upload_dir(), Path.basename(file)))
end
