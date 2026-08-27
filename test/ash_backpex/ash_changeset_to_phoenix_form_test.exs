defmodule AshBackpex.AshChangesetToPhoenixFormTest do
  use ExUnit.Case, async: true

  alias AshBackpex.TestDomain.{
    Comment,
    EmbeddedColumn,
    EmbeddedPage,
    EmbeddedSection,
    EmbeddedTarget,
    Post
  }

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
    assert nested_form.options[:ash_resource] == Comment
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

    assert Enum.all?(nested_forms, &(&1.options[:ash_resource] == Comment))
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

  test "reconstructs loaded repeated and singular embeds from each nested resource" do
    target = %EmbeddedTarget{kind: :internal, path: "/loaded"}
    column = %EmbeddedColumn{heading: "Loaded column", target: target}
    section = %EmbeddedSection{title: "Loaded section", columns: [column]}
    page = %EmbeddedPage{id: Ash.UUID.generate(), title: "Page", sections: [section]}

    changeset = Ash.Changeset.new(page)
    form = Phoenix.Component.to_form(changeset, as: :change)

    assert [section_form] = Phoenix.HTML.FormData.to_form(changeset, form, :sections, [])
    assert section_form.data == section
    assert section_form.options[:ash_resource] == EmbeddedSection
    assert section_form.options[:ash_form_path] == [:sections, 0]
    assert Phoenix.HTML.Form.input_value(section_form, :title) == "Loaded section"

    assert [column_form] =
             Phoenix.HTML.FormData.to_form(changeset, section_form, :columns, [])

    assert column_form.data == column
    assert column_form.options[:ash_resource] == EmbeddedColumn
    assert column_form.options[:ash_form_path] == [:sections, 0, :columns, 0]
    assert Phoenix.HTML.Form.input_value(column_form, :heading) == "Loaded column"

    assert [target_form] =
             Phoenix.HTML.FormData.to_form(changeset, column_form, :target, [])

    assert target_form.data == target
    assert target_form.options[:ash_resource] == EmbeddedTarget
    assert target_form.options[:ash_form_path] == [:sections, 0, :columns, 0, :target]
    assert Phoenix.HTML.Form.input_value(target_form, :kind) == :internal
    assert Phoenix.HTML.Form.input_value(target_form, :path) == "/loaded"
  end

  test "reconstructs submitted nested lists and maps before loaded defaults" do
    loaded_target = %EmbeddedTarget{kind: :internal, path: "/loaded"}
    loaded_column = %EmbeddedColumn{heading: "Loaded column", target: loaded_target}
    loaded_section = %EmbeddedSection{title: "Loaded section", columns: [loaded_column]}

    page = %EmbeddedPage{
      id: Ash.UUID.generate(),
      title: "Page",
      sections: [loaded_section]
    }

    submitted_sections = [
      %{
        "_persistent_id" => "section-b",
        "title" => "Submitted second",
        "columns" => %{
          "0" => %{
            "_persistent_id" => "column-b",
            "heading" => "Submitted column",
            "target" => %{"kind" => "external", "path" => "/submitted"}
          }
        }
      },
      %{
        "_persistent_id" => "section-a",
        "title" => "New row",
        "columns" => []
      }
    ]

    changeset = %{Ash.Changeset.new(page) | params: %{"sections" => submitted_sections}}
    form = Phoenix.Component.to_form(changeset, as: :change, action: :validate)

    assert [section_b, section_a] =
             Phoenix.HTML.FormData.to_form(changeset, form, :sections, [])

    assert Enum.map([section_b, section_a], & &1.params["_persistent_id"]) == [
             "section-b",
             "section-a"
           ]

    assert Enum.map([section_b, section_a], &Phoenix.HTML.Form.input_value(&1, :title)) == [
             "Submitted second",
             "New row"
           ]

    assert [column_form] =
             Phoenix.HTML.FormData.to_form(changeset, section_b, :columns, [])

    assert column_form.params["_persistent_id"] == "column-b"
    assert Phoenix.HTML.Form.input_value(column_form, :heading) == "Submitted column"

    assert [target_form] =
             Phoenix.HTML.FormData.to_form(changeset, column_form, :target, [])

    assert target_form.params == %{"kind" => "external", "path" => "/submitted"}
    assert Phoenix.HTML.Form.input_value(target_form, :kind) == "external"
    assert Phoenix.HTML.Form.input_value(target_form, :path) == "/submitted"

    assert Phoenix.HTML.FormData.to_form(changeset, section_a, :columns, []) == []
  end

  test "preserves an explicitly submitted empty repeated embed" do
    section = %EmbeddedSection{title: "Loaded section", columns: []}
    page = %EmbeddedPage{id: Ash.UUID.generate(), title: "Page", sections: [section]}
    changeset = %{Ash.Changeset.new(page) | params: %{"sections" => []}}
    form = Phoenix.Component.to_form(changeset, as: :change)

    assert Phoenix.HTML.FormData.to_form(changeset, form, :sections, []) == []
  end

  test "singular embeds do not read same-named values from the root changeset" do
    target = %EmbeddedTarget{kind: :internal, path: "/nested"}
    column = %EmbeddedColumn{heading: "Column", target: target}
    section = %EmbeddedSection{title: "Section", columns: [column]}
    page = %EmbeddedPage{id: Ash.UUID.generate(), title: "Page", sections: [section]}
    changeset = %{Ash.Changeset.new(page) | attributes: %{path: "/root"}}
    form = Phoenix.Component.to_form(changeset, as: :change)

    [section_form] = Phoenix.HTML.FormData.to_form(changeset, form, :sections, [])
    [column_form] = Phoenix.HTML.FormData.to_form(changeset, section_form, :columns, [])
    [target_form] = Phoenix.HTML.FormData.to_form(changeset, column_form, :target, [])

    assert Phoenix.HTML.Form.input_value(target_form, :path) == "/nested"
  end

  test "routes a path-aware embedded error to the exact repeated row and singular form" do
    params = %{
      "sections" => [
        %{
          "_persistent_id" => "section-0",
          "title" => "Section",
          "columns" => [
            %{
              "_persistent_id" => "column-0",
              "heading" => "Valid",
              "target" => %{"kind" => "internal", "path" => "/valid"}
            },
            %{
              "_persistent_id" => "column-1",
              "heading" => "Invalid",
              "target" => %{"kind" => "unsupported", "path" => "/invalid"}
            }
          ]
        }
      ]
    }

    changeset =
      %EmbeddedPage{}
      |> Ash.Changeset.new()
      |> Ash.Changeset.change_attribute(:sections, params["sections"])
      |> Map.put(:params, params)

    form = Phoenix.Component.to_form(changeset, as: :change, action: :validate)
    [section_form] = Phoenix.HTML.FormData.to_form(changeset, form, :sections, [])

    assert [valid_column, invalid_column] =
             Phoenix.HTML.FormData.to_form(changeset, section_form, :columns, [])

    [valid_target] = Phoenix.HTML.FormData.to_form(changeset, valid_column, :target, [])
    [invalid_target] = Phoenix.HTML.FormData.to_form(changeset, invalid_column, :target, [])

    assert valid_target.errors == []
    assert invalid_target.options[:ash_form_path] == [:sections, 0, :columns, 1, :target]
    assert [{:kind, message}] = invalid_target.errors
    assert message =~ "internal, external"
    assert invalid_target[:kind].errors == [message]
  end
end
