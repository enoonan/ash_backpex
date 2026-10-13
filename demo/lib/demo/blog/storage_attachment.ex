defmodule Demo.Blog.StorageAttachment do
  @moduledoc """
  Links an AshStorage blob to the post it is attached to.
  """
  use Ash.Resource,
    domain: Demo.Blog,
    data_layer: AshSqlite.DataLayer,
    extensions: [AshStorage.AttachmentResource]

  sqlite do
    table "storage_attachments"
    repo(Demo.Repo)

    references do
      reference(:post, on_delete: :nilify)
    end
  end

  attachment do
    blob_resource(Demo.Blog.StorageBlob)
    belongs_to_resource(:post, Demo.Blog.Post)
  end

  attributes do
    uuid_primary_key :id
  end
end
