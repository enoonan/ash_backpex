defmodule AshBackpex.Filters.FilterBadgeTest do
  @moduledoc """
  Mounts an index with filters in the URL and reads the badges Backpex renders.
  Backpex calls a filter's `render/1` with the render context and the value only,
  so these tests run against the context Backpex builds, not a hand-built one.
  """
  use AshBackpex.DataCase, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias AshBackpex.TestDomain.User

  @endpoint AshBackpex.TestEndpoint

  setup_all do
    start_supervised!({Phoenix.PubSub, name: AshBackpex.TestPubSub})
    start_supervised!(AshBackpex.TestEndpoint)
    :ok
  end

  setup do
    user =
      User
      |> Ash.Changeset.for_create(:create, %{name: "Ada", email: "ada@example.com", active: true})
      |> Ash.create!()

    %{user: user}
  end

  @selected "filters[status]=published&filters[tags][]=food&filters[tags][]=politics"

  test "Select and MultiSelect badges show the labels of the selected options", %{user: user} do
    assert badges(user, "/filter-badges?#{@selected}") == [
             {"Status", "Published"},
             {"Tags", "Food, Politics"}
           ]
  end

  test "badges show the labels when context_assigns is a list of keys", %{user: user} do
    assert badges(user, "/filter-badges-context-keys?#{@selected}") == [
             {"Status", "Published"},
             {"Tags", "Food, Politics"}
           ]
  end

  test "badges show the labels derived from one_of constraints", %{user: user} do
    path =
      "/filter-badges-derived?filters[status]=archived&filters[tags][]=entertainment"

    assert badges(user, path) == [{"Status", "Archived"}, {"Tags", "Entertainment"}]
  end

  # Known limitation: without the field, a badge takes the label of the first
  # filter that lists the value, so both badges show the same label and one of
  # them is wrong. This pins the behavior until Backpex passes the field to
  # `render/1`.
  test "a value shared by two filters shows one label on both badges", %{user: user} do
    path = "/filter-badges-shared-value?filters[status]=draft&filters[title]=draft"

    assert [{"Status", label}, {"Title", label}] = badges(user, path)
    assert label in ["Draft status", "Draft title"]
  end

  # Returns each rendered badge as `{filter label, value label}`.
  defp badges(user, path) do
    {:ok, _view, html} =
      build_conn()
      |> Plug.Test.init_test_session(%{"current_user_id" => user.id})
      |> live(path)

    html
    |> LazyHTML.from_document()
    |> LazyHTML.query(".indicator > .join")
    |> Enum.map(fn badge ->
      [label, value] =
        badge
        |> LazyHTML.query(".join-item")
        |> Enum.map(&(&1 |> LazyHTML.text() |> String.trim()))

      {label, value}
    end)
  end
end
