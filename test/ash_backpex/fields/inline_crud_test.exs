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

  test "uses a wrapping child grid and gives structural children a full row" do
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

    assert html =~ "grid-cols-[repeat(auto-fit,minmax(min(100%,16rem),1fr))]"
    assert html =~ "min-w-0"
    assert length(Regex.scan(~r/class="col-span-full"/, html)) == 2
  end

  test "groups repeated entries and names their controls by entry type" do
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

    assert html =~ "inline-crud-entry inline-crud-entry--bounded mb-4 min-w-0"
    assert html =~ "inline-crud-entry-actions"
    assert length(Regex.scan(~r/style="gap: 0.375rem"/, html)) >= 4
    assert html =~ ~s(aria-label="Add Sections")
    assert html =~ ~s(aria-label="Add Page columns")
    assert html =~ ~s(aria-label="Move Sections up")
    assert html =~ ~s(aria-label="Delete Page columns")
  end

  test "stacks singular embedded child labels above full-width controls" do
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
                "target" => %{"kind" => "unsupported"}
              }
            ]
          }
        ]
      })

    assert html =~ ~s(id="embedded-fieldset-change_sections_section-a_columns_column-a_target")
    assert html =~ "embedded-fieldset"
    assert html =~ "w-full min-w-0"
    assert html =~ "[&_dl]:!flex-col"
    assert html =~ "[&_dt]:!w-full"
    assert html =~ "[&_dd]:!w-full"
    assert html =~ ~s(for="change_sections_section-a_columns_column-a_target_kind")
    assert html =~ ~s(for="change_sections_section-a_columns_column-a_target_path")
    assert html =~ ~s(name="change[sections][0][columns][0][target][kind]")
    assert html =~ ~s(name="change[sections][0][columns][0][target][path]")
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
    assert html =~ ~s(class="min-w-0 flex-1")
  end

  test "treats an unloaded has-many relationship as empty on a new form" do
    changeset = Ash.Changeset.for_create(Post, :create, %{title: "Post"})
    assert %Ash.NotLoaded{} = changeset.data.comments

    form = Phoenix.Component.to_form(changeset, as: :change)
    field_options = Backpex.LiveResource.fields(TestInlineCrudLive, :new, %{})[:comments]

    html =
      render_component(AshBackpex.Fields.InlineCRUD, %{
        id: "new-post-comments",
        type: :form,
        name: :comments,
        field: {:comments, field_options},
        field_options: field_options,
        form: form,
        item: changeset.data,
        live_action: :new,
        live_resource: TestInlineCrudLive
      })

    assert html =~ ~s(aria-label="Add Comments")
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
