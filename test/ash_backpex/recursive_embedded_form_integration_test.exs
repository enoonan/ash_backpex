defmodule AshBackpex.RecursiveEmbeddedFormIntegrationTest do
  use AshBackpex.DataCase, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint AshBackpex.TestEndpoint

  setup_all do
    start_supervised!(AshBackpex.TestEndpoint)
    :ok
  end

  test "validates and operates on repeated, repeated, and singular embedded forms" do
    {:ok, view, initial_html} = start_view()

    assert initial_html =~ ~s(name="change[sections][0][columns][0][target][kind]")

    moved_nested =
      view
      |> change_form(params(columns_move_down: ["0"]))
      |> render_change()

    assert before?(moved_nested, "Second column", "First column")
    assert moved_nested =~ ~s(name="change[sections][0][columns_move_down][]")

    {:ok, view, _html} = start_view()

    moved_top =
      view
      |> change_form(params(sections_move_down: ["0"]))
      |> render_change()

    assert before?(moved_top, "Second section", "First section")

    {:ok, view, _html} = start_view()

    deleted_nested =
      view
      |> change_form(params(columns_delete: ["0"]))
      |> render_change()

    refute deleted_nested =~ ">First column</textarea>"
    assert deleted_nested =~ ">Second column</textarea>"

    {:ok, view, _html} = start_view()

    added_nested =
      view
      |> change_form(params(columns_order: ["0", "1", "on"]))
      |> render_change()

    assert added_nested =~ ~s(name="change[sections][0][columns][2][heading]")

    {:ok, view, _html} = start_view()

    added_top =
      view
      |> change_form(params(sections_order: ["0", "1", "on"]))
      |> render_change()

    assert added_top =~ ~s(name="change[sections][2][title]")

    {:ok, view, _html} = start_view()

    invalid = render_change(view, "validate", %{"change" => params(invalid_kind: true)})

    assert invalid =~ "unsupported"
    assert invalid =~ "internal, external"
    assert invalid =~ "inline-crud-entry-change_sections_0"
    assert invalid =~ "inline-crud-entry-change_sections_0_columns_0"
  end

  defp start_view, do: live_isolated(build_conn(), TestRecursiveEmbeddedFormLive)

  defp change_form(view, params), do: form(view, "#recursive-embedded-form", change: params)

  defp params(options) do
    invalid_kind? = Keyword.get(options, :invalid_kind, false)

    %{
      "sections" => %{
        "0" => %{
          "_persistent_id" => "0",
          "title" => "First section",
          "columns" => %{
            "0" => %{
              "_persistent_id" => "0",
              "heading" => "First column",
              "target" => %{
                "kind" => if(invalid_kind?, do: "unsupported", else: "internal")
              }
            },
            "1" => %{
              "_persistent_id" => "1",
              "heading" => "Second column",
              "target" => %{"kind" => "external"}
            }
          },
          "columns_order" => Keyword.get(options, :columns_order, ["0", "1"]),
          "columns_delete" => Keyword.get(options, :columns_delete, []),
          "columns_move_down" => Keyword.get(options, :columns_move_down, [])
        },
        "1" => %{
          "_persistent_id" => "1",
          "title" => "Second section",
          "columns" => %{},
          "columns_order" => []
        }
      },
      "sections_order" => Keyword.get(options, :sections_order, ["0", "1"]),
      "sections_delete" => [],
      "sections_move_down" => Keyword.get(options, :sections_move_down, [])
    }
  end

  defp before?(html, left, right) do
    :binary.match(html, left) < :binary.match(html, right)
  end
end
