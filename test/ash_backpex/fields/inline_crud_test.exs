defmodule AshBackpex.Fields.InlineCRUDTest do
  use AshBackpex.DataCase, async: false

  import Phoenix.LiveViewTest

  alias AshBackpex.TestDomain.{EmbeddedPage, Post}

  test "renders recursive controls and inputs from the current nested form path" do
    html =
      render_recursive_form(%{
        "sections" => [
          %{
            "_persistent_id" => "section-a",
            "title" => "Section",
            "columns" => [
              %{
                "_persistent_id" => "column-a",
                "heading" => "Column",
                "target" => %{"kind" => "internal"}
              }
            ]
          }
        ]
      })

    assert html =~ ~s(name="change[sections][0][columns_order][]")
    assert html =~ ~s(name="change[sections][0][columns_delete][]")
    assert html =~ ~s(name="change[sections][0][columns_move_up][]")
    assert html =~ ~s(name="change[sections][0][columns_move_down][]")
    refute html =~ ~s(name="change[columns_order][]")

    assert html =~ ~s(name="change[sections][0][columns][0][heading]")
    assert html =~ ~s(name="change[sections][0][columns][0][target][kind]")
    assert html =~ "section-a"
    assert html =~ "column-a"
  end

  test "keeps repeated row DOM ids stable when submitted rows are reordered" do
    first =
      render_recursive_form(%{
        "sections" => [
          section_params("section-a", "First"),
          section_params("section-b", "Second")
        ]
      })

    reordered =
      render_recursive_form(%{
        "sections" => [
          section_params("section-b", "Second"),
          section_params("section-a", "First")
        ]
      })

    assert row_id(first, "section-a") == row_id(reordered, "section-a")
    assert row_id(first, "section-b") == row_id(reordered, "section-b")
  end

  test "evaluates visibility, authorization, and readonly callbacks with each nested form" do
    test_pid = self()

    field_options =
      TestRecursiveEmbeddedLive.fields()[:sections]
      |> update_child(:columns, fn options ->
        Map.put(options, :can?, fn assigns ->
          send(test_pid, {:columns_can, assigns.form.name})
          true
        end)
      end)
      |> update_grandchild(:columns, :target, fn options ->
        Map.put(options, :visible, fn assigns ->
          send(test_pid, {:target_visible, assigns.form.name})
          true
        end)
      end)
      |> update_great_grandchild(:columns, :target, :kind, fn options ->
        options
        |> Map.put(:can?, fn assigns ->
          send(test_pid, {:kind_can, assigns.form.name})
          true
        end)
      end)
      |> update_great_grandchild(:columns, :target, :path, fn options ->
        Map.put(options, :readonly, fn assigns ->
          send(test_pid, {:kind_readonly, assigns.form.name})
          true
        end)
      end)

    html =
      render_recursive_form(
        %{
          "sections" => [
            %{
              "_persistent_id" => "section-a",
              "title" => "Section",
              "columns" => [
                %{
                  "_persistent_id" => "column-a",
                  "heading" => "Column",
                  "target" => %{"kind" => "internal"}
                }
              ]
            }
          ]
        },
        field_options
      )

    assert_receive {:columns_can, "change[sections][0]"}
    assert_receive {:target_visible, "change[sections][0][columns][0]"}
    assert_receive {:kind_can, "change[sections][0][columns][0][target]"}
    assert_receive {:kind_readonly, "change[sections][0][columns][0][target]"}

    assert html =~
             ~r/<input[^>]+name="change\[sections\]\[0\]\[columns\]\[0\]\[target\]\[path\]"[^>]+disabled/
  end

  test "renders translated validation errors beside the submitted singular child value" do
    field_options =
      TestRecursiveEmbeddedLive.fields()[:sections]
      |> update_great_grandchild(:columns, :target, :kind, fn options ->
        Map.put(options, :translate_error, fn _error -> "Translated nested kind" end)
      end)

    params = %{
      "sections" => [
        %{
          "_persistent_id" => "section-a",
          "title" => "Section",
          "columns" => [
            %{
              "_persistent_id" => "column-a",
              "heading" => "Column",
              "target" => %{"kind" => "unsupported"}
            }
          ]
        }
      ]
    }

    changeset =
      EmbeddedPage
      |> Ash.Changeset.for_create(:create, params)
      |> Map.put(:action, :validate)

    html = render_recursive_form(params, field_options, changeset)

    assert html =~ "Translated nested kind"
    assert html =~ "inline-crud-entry-change_sections_section-a_columns_column-a"
  end

  test "keeps one-level relationship InlineCRUD names and hidden primary keys compatible" do
    comment_id = Ash.UUID.generate()
    post = %Post{id: Ash.UUID.generate(), title: "Post", comments: []}

    changeset =
      %{
        Ash.Changeset.new(post)
        | params: %{"comments" => [%{"id" => comment_id, "body" => "Body"}]}
      }

    form = Phoenix.Component.to_form(changeset, as: :change)
    field_options = Backpex.LiveResource.fields(TestInlineCrudLive, :edit, %{})[:comments]

    html =
      render_component(AshBackpex.Fields.InlineCRUD, %{
        id: "post-comments",
        type: :form,
        name: :comments,
        field: {:comments, field_options},
        field_options: field_options,
        form: form,
        item: post,
        live_action: :edit,
        live_resource: TestInlineCrudLive
      })

    assert html =~ ~s(name="change[comments_order][]")
    assert html =~ ~s(name="change[comments_delete][]")
    assert html =~ ~s(name="change[comments][0][body]")
    assert html =~ ~s(name="change[comments][0][id]" value="#{comment_id}")
  end

  defp render_recursive_form(params, field_options \\ nil, changeset \\ nil) do
    page = %EmbeddedPage{id: Ash.UUID.generate(), title: "Page", sections: []}
    changeset = changeset || %{Ash.Changeset.new(page) | params: params, action: :validate}
    form = Phoenix.Component.to_form(changeset, as: :change, action: :validate)

    field_options =
      field_options ||
        Backpex.LiveResource.fields(TestRecursiveEmbeddedLive, :edit, %{})[:sections]

    render_component(AshBackpex.Fields.InlineCRUD, %{
      id: "recursive-sections",
      type: :form,
      name: :sections,
      field: {:sections, field_options},
      field_options: field_options,
      form: form,
      item: page,
      live_action: :edit,
      live_resource: TestRecursiveEmbeddedLive
    })
  end

  defp section_params(persistent_id, title) do
    %{
      "_persistent_id" => persistent_id,
      "title" => title,
      "columns" => [
        %{
          "_persistent_id" => "#{persistent_id}-column",
          "heading" => "#{title} column",
          "target" => %{"kind" => "internal"}
        }
      ]
    }
  end

  defp row_id(html, persistent_id) do
    ~r/id="(inline-crud-entry-[^"]*#{Regex.escape(persistent_id)}[^"]*)"/
    |> Regex.run(html, capture: :all_but_first)
    |> List.first()
  end

  defp update_child(options, child, update) do
    Map.update!(options, :child_fields, &Keyword.update!(&1, child, update))
  end

  defp update_grandchild(options, child, grandchild, update) do
    update_child(options, child, &update_child(&1, grandchild, update))
  end

  defp update_great_grandchild(options, child, grandchild, great_grandchild, update) do
    update_child(options, child, fn child_options ->
      update_grandchild(child_options, grandchild, great_grandchild, update)
    end)
  end
end
