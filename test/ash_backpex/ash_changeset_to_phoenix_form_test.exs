defmodule AshBackpex.AshChangesetToPhoenixFormTest do
  use ExUnit.Case, async: true

  alias AshBackpex.TestDomain.{Comment, Post}

  test "builds cardinality-many forms from a loaded Ash relationship" do
    post_author_id = Ash.UUID.generate()
    comment_author_id = Ash.UUID.generate()
    comment = %Comment{id: Ash.UUID.generate(), body: "First", author_id: comment_author_id}

    post = %Post{
      id: Ash.UUID.generate(),
      title: "Post",
      author_id: post_author_id,
      comments: [comment]
    }

    changeset = Ash.Changeset.for_update(post, :update, %{})
    form = Phoenix.Component.to_form(changeset, as: :change)

    assert [nested_form] =
             Phoenix.HTML.FormData.to_form(changeset, form, :comments, [])

    assert nested_form.data == comment
    assert nested_form.hidden == [id: comment.id]
    assert Phoenix.HTML.Form.input_value(nested_form, :body) == "First"
    assert Phoenix.HTML.Form.input_value(nested_form, :author_id) == comment_author_id
  end

  test "builds nested forms from normalized relationship params" do
    post = %Post{id: Ash.UUID.generate(), title: "Post", comments: []}
    changeset = Ash.Changeset.for_update(post, :update, %{})
    form = Phoenix.Component.to_form(changeset, as: :change)

    form = %{
      form
      | params: %{"comments" => [%{"body" => "First"}, %{"body" => "Second"}]}
    }

    nested_forms = Phoenix.HTML.FormData.to_form(changeset, form, :comments, default: [])

    assert Enum.map(nested_forms, & &1.params["body"]) == ["First", "Second"]
  end

  test "keeps child primary keys hidden after nested params are submitted" do
    comment_id = Ash.UUID.generate()
    post = %Post{id: Ash.UUID.generate(), title: "Post", comments: []}
    changeset = Ash.Changeset.for_update(post, :update, %{})
    form = Phoenix.Component.to_form(changeset, as: :change)

    form = %{
      form
      | params: %{
          "comments" => [%{"id" => comment_id, "body" => "Edited"}]
        }
    }

    assert [nested_form] =
             Phoenix.HTML.FormData.to_form(changeset, form, :comments, default: [])

    assert nested_form.hidden == [id: comment_id]
  end
end
