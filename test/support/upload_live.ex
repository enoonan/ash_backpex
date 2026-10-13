defmodule TestDocumentUploadLive do
  @moduledoc false
  use AshBackpex.LiveResource

  # Uploaded files are copied here, and the `file` attribute stores their name.
  def upload_dir, do: Path.join(System.tmp_dir!(), "ash_backpex_test_uploads")

  backpex do
    resource AshBackpex.TestDomain.Document
    layout({TestIndexEditLayout, :admin})
    pubsub(server: AshBackpex.TestPubSub)

    fields do
      field :title

      field :file, Backpex.Fields.Upload do
        upload_key(:file)
        accept(~w(.txt))
        max_entries(1)
        max_file_size(1_000)
        list_existing_files(&__MODULE__.list_existing_files/1)
        file_label(&__MODULE__.file_label/1)
        put_upload_change(&__MODULE__.put_upload_change/6)
        consume_upload(&__MODULE__.consume_upload/4)
        remove_uploads(&__MODULE__.remove_uploads/3)
      end
    end
  end

  def list_existing_files(%{file: file}) when is_binary(file), do: [file]
  def list_existing_files(_item), do: []

  def file_label(file), do: "uploaded " <> file

  def put_upload_change(_socket, params, item, uploaded_entries, removed_entries, action) do
    existing_files = list_existing_files(item) -- removed_entries

    new_entries =
      case action do
        :validate -> elem(uploaded_entries, 1)
        :insert -> elem(uploaded_entries, 0)
      end

    files = existing_files ++ Enum.map(new_entries, & &1.client_name)

    case files do
      [file | _other_files] -> Map.put(params, "file", file)
      [] -> Map.put(params, "file", nil)
    end
  end

  def consume_upload(_socket, _item, %{path: path}, entry) do
    File.mkdir_p!(upload_dir())
    File.cp!(path, Path.join(upload_dir(), entry.client_name))

    {:ok, entry.client_name}
  end

  def remove_uploads(_socket, _item, removed_entries) do
    for file <- removed_entries, do: File.rm(Path.join(upload_dir(), file))
  end
end

defmodule TestDocumentAttachmentsLive do
  @moduledoc false
  use AshBackpex.LiveResource

  backpex do
    resource AshBackpex.TestDomain.Document
    layout({TestIndexEditLayout, :admin})
    pubsub(server: AshBackpex.TestPubSub)

    fields do
      field :title

      field :attachments, Backpex.Fields.Upload do
        accept(~w(.txt))
        max_entries(3)
        max_file_size(1_000)
        list_existing_files(&__MODULE__.list_existing_files/1)
        put_upload_change(&__MODULE__.put_upload_change/6)
        consume_upload(&__MODULE__.consume_upload/4)
        remove_uploads(&__MODULE__.remove_uploads/3)
      end
    end
  end

  def list_existing_files(%{attachments: attachments}) when is_list(attachments),
    do: attachments

  def list_existing_files(_item), do: []

  def put_upload_change(_socket, params, item, uploaded_entries, removed_entries, action) do
    existing_files = list_existing_files(item) -- removed_entries

    new_entries =
      case action do
        :validate -> elem(uploaded_entries, 1)
        :insert -> elem(uploaded_entries, 0)
      end

    Map.put(params, "attachments", existing_files ++ Enum.map(new_entries, & &1.client_name))
  end

  def consume_upload(socket, item, meta, entry),
    do: TestDocumentUploadLive.consume_upload(socket, item, meta, entry)

  def remove_uploads(socket, item, removed_entries),
    do: TestDocumentUploadLive.remove_uploads(socket, item, removed_entries)
end
