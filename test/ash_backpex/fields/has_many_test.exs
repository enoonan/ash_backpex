defmodule AshBackpex.Fields.HasManyTest do
  # The test repo is SQLite, which has no `ilike`, so these tests drive the
  # option search Backpex writes with `ilike` and would crash on.
  use AshBackpex.DataCase, async: false

  import Ecto.Query
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias AshBackpex.TestDomain.ManyToManyPost

  @endpoint AshBackpex.TestEndpoint

  setup_all do
    start_supervised!({Phoenix.PubSub, name: AshBackpex.TestPubSub})
    start_supervised!(AshBackpex.TestEndpoint)
    :ok
  end

  test "is the default field for has_many and many_to_many relationships" do
    assert TestManyToManySearchLive.fields()[:categories].module == AshBackpex.Fields.HasMany
    assert TestManyToManySearchLive.fields()[:all_categories].module == AshBackpex.Fields.HasMany
  end

  test "an explicit Backpex.Fields.HasMany module is kept" do
    assert TestExplicitBackpexHasManyLive.fields()[:all_categories].module ==
             Backpex.Fields.HasMany
  end

  test "searches a filtered relationship's options" do
    beta = insert_category!("Beta", "assignable")
    insert_category!("Gamma", "assignable")
    insert_category!("Betamax", "internal")

    {:ok, view, _html} = live(conn(), "/many-to-many-posts/new")

    search(view, :categories, "BET")

    assert option_labels(view, :categories) == ["Beta"]
    assert has_element?(view, "#has-many-categories-checkbox-value-#{beta}")
  end

  test "searches an unfiltered relationship's options" do
    insert_category!("Beta", "assignable")
    insert_category!("Gamma", "assignable")
    insert_category!("Betamax", "internal")

    {:ok, view, _html} = live(conn(), "/many-to-many-posts/new")

    search(view, :all_categories, "bet")

    assert Enum.sort(option_labels(view, :all_categories)) == ["Beta", "Betamax"]
  end

  test "an empty search shows every option again" do
    insert_category!("Beta", "assignable")
    insert_category!("Gamma", "assignable")

    {:ok, view, _html} = live(conn(), "/many-to-many-posts/new")

    search(view, :all_categories, "bet")
    search(view, :all_categories, "")

    assert Enum.sort(option_labels(view, :all_categories)) == ["Beta", "Gamma"]
  end

  test "show more loads the next page of matching options while searching" do
    for n <- 1..12,
        do: insert_category!("Match #{String.pad_leading("#{n}", 2, "0")}", "internal")

    for n <- 1..3, do: insert_category!("Other #{n}", "internal")

    {:ok, view, _html} = live(conn(), "/many-to-many-posts/new")

    search(view, :all_categories, "match")

    assert length(option_labels(view, :all_categories)) == 10
    assert has_element?(view, "#has-many-all_categories button", "Show more")

    view |> element("#has-many-all_categories button", "Show more") |> render_click()

    labels = option_labels(view, :all_categories)
    assert length(labels) == 12
    assert Enum.all?(labels, &String.starts_with?(&1, "Match"))
    refute has_element?(view, "#has-many-all_categories button", "Show more")
  end

  test "saves options selected after a search" do
    beta = insert_category!("Beta", "assignable")
    insert_category!("Gamma", "assignable")

    {:ok, view, _html} = live(conn(), "/many-to-many-posts/new")

    search(view, :all_categories, "bet")

    assert {:error, {:live_redirect, %{to: "/many-to-many-posts"}}} =
             view
             |> form("#resource-form", change: %{title: "Searched", all_categories: [beta]})
             |> render_submit(%{"save-type" => "save"})

    [post] = Ash.read!(ManyToManyPost, load: :all_categories)
    assert Enum.map(post.all_categories, & &1.id) == [beta]
  end

  test "searches through the select option" do
    insert_category!("Beta", "assignable")
    betamax = insert_category!("Betamax", "internal")

    {name, options} =
      field =
      {:all_categories,
       Map.put(
         TestManyToManySearchLive.fields()[:all_categories],
         :select,
         dynamic([manytomanycategory: category], category.type)
       )}

    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        name: name,
        field: field,
        field_options: options,
        live_resource: TestManyToManySearchLive,
        search_input: "",
        offset: 0,
        options: []
      }
    }

    {:noreply, socket} =
      AshBackpex.Fields.HasMany.handle_event(
        "search",
        %{"all_categories_search" => "INTERN"},
        socket
      )

    assert socket.assigns.options == [{"Betamax", betamax}]
    assert socket.assigns.options_ids == [betamax]
    assert socket.assigns.search_input == "INTERN"
    refute socket.assigns.show_more
  end

  defp search(view, name, text) do
    view
    |> element("#has-many-#{name} input[type=search]")
    |> render_change(%{"#{name}_search" => text})
  end

  defp option_labels(view, name) do
    view
    |> element("#has-many-#{name}")
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("span.label-text")
    |> Enum.map(&(&1 |> LazyHTML.text() |> String.trim()))
  end

  defp insert_category!(name, type) do
    id = Ash.UUID.generate()

    Ecto.Adapters.SQL.query!(
      TestRepo,
      "INSERT INTO many_to_many_categories (id, name, type) VALUES (?, ?, ?)",
      [id, name, type]
    )

    id
  end

  defp conn, do: init_test_session(build_conn(), %{})
end
