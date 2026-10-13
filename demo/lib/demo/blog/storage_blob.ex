defmodule Demo.Blog.StorageBlob do
  @moduledoc """
  File metadata for AshStorage: one row per stored file.
  """
  use Ash.Resource,
    domain: Demo.Blog,
    data_layer: AshSqlite.DataLayer,
    extensions: [AshStorage.BlobResource]

  sqlite do
    table "storage_blobs"
    repo(Demo.Repo)
  end

  blob do
  end

  attributes do
    uuid_primary_key :id
  end
end
