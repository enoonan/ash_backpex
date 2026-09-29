defmodule Demo.Repo.Migrations.CascadePostDeletes do
  @moduledoc """
  Deletes a post's tag links and comments along with the post.

  The resource snapshots were generated with `mix ash.codegen`, but SQLite cannot
  alter an existing foreign key constraint, so the generated steps were replaced
  with SQLite's table rebuild: create the new table, copy the rows, drop the old
  table, and rename the new one. No other table references `post_tags` or
  `comments`, so the rebuild is safe with foreign keys enabled.
  """

  use Ecto.Migration

  def up do
    rebuild_post_tags("ON DELETE CASCADE")
    rebuild_comments("ON DELETE CASCADE")
  end

  def down do
    rebuild_post_tags("")
    rebuild_comments("")
  end

  defp rebuild_post_tags(on_delete) do
    execute("""
    CREATE TABLE "post_tags_new" (
      "tag_id" TEXT NOT NULL CONSTRAINT "post_tags_tag_id_fkey" REFERENCES "tags"("id"),
      "post_id" TEXT NOT NULL CONSTRAINT "post_tags_post_id_fkey" REFERENCES "posts"("id") #{on_delete},
      PRIMARY KEY ("tag_id", "post_id")
    )
    """)

    execute(
      ~s|INSERT INTO "post_tags_new" ("tag_id", "post_id") SELECT "tag_id", "post_id" FROM "post_tags"|
    )

    execute(~s|DROP TABLE "post_tags"|)
    execute(~s|ALTER TABLE "post_tags_new" RENAME TO "post_tags"|)
  end

  defp rebuild_comments(on_delete) do
    execute("""
    CREATE TABLE "comments_new" (
      "author_id" TEXT NOT NULL CONSTRAINT "comments_author_id_fkey" REFERENCES "authors"("id"),
      "post_id" TEXT NOT NULL CONSTRAINT "comments_post_id_fkey" REFERENCES "posts"("id") #{on_delete},
      "updated_at" TEXT NOT NULL,
      "inserted_at" TEXT NOT NULL,
      "approved" INTEGER NOT NULL,
      "sentiment" TEXT NOT NULL,
      "body" TEXT NOT NULL,
      "id" TEXT NOT NULL PRIMARY KEY
    )
    """)

    execute("""
    INSERT INTO "comments_new"
      ("author_id", "post_id", "updated_at", "inserted_at", "approved", "sentiment", "body", "id")
    SELECT "author_id", "post_id", "updated_at", "inserted_at", "approved", "sentiment", "body", "id"
    FROM "comments"
    """)

    execute(~s|DROP TABLE "comments"|)
    execute(~s|ALTER TABLE "comments_new" RENAME TO "comments"|)
  end
end
