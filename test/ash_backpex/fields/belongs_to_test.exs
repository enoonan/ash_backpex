defmodule AshBackpex.Fields.BelongsToTest do
  use AshBackpex.DataCase, async: false

  import Phoenix.LiveViewTest

  alias AshBackpex.Fields.BelongsTo
  alias AshBackpex.TestDomain.{Comment, Post, User}

  setup do
    previous_translator = Application.get_env(:backpex, :translator_function)
    Application.put_env(:backpex, :translator_function, {__MODULE__, :translate})

    on_exit(fn ->
      if previous_translator do
        Application.put_env(:backpex, :translator_function, previous_translator)
      else
        Application.delete_env(:backpex, :translator_function)
      end
    end)
  end

  test "updates index fields without requiring form assigns" do
    field_options = TestTypeaheadLive.fields()[:author]

    assigns = %{
      type: :index,
      name: :author,
      field: {:author, field_options},
      field_options: field_options,
      live_resource: TestTypeaheadLive
    }

    assert {:ok, socket} = BelongsTo.update(assigns, component_socket())
    assert socket.assigns.queryable == User
    assert socket.assigns.owner_key == :author_id
    assert socket.assigns.related_key == :id
    refute Map.has_key?(socket.assigns, :selected_id)
  end

  test "loads index-editable options once per page through Backpex index_assigns/3" do
    ada = seed_user!("Ada", "ada@example.com")
    post = %Post{id: Ash.UUID.generate(), author_id: ada.id}

    field_options =
      TestTypeaheadLive.fields()[:author]
      |> Map.put(:index_editable, true)

    assigns = %{live_action: :index, live_resource: TestTypeaheadLive}

    assert %{index_form_options: %{} = options_by_item} =
             BelongsTo.index_assigns({:author, field_options}, [post], assigns)

    assert {"Ada", ada.id} in Map.fetch!(options_by_item, post.id)

    assert BelongsTo.index_assigns(
             {:author, Map.put(field_options, :index_editable, false)},
             [post],
             assigns
           ) == %{}
  end

  test "renders the search inside the resource form with single-select options" do
    form = Phoenix.Component.to_form(%{"author_id" => "selected-id"}, as: :change)

    html =
      render_component(&BelongsTo.render_form/1, %{
        form: form,
        owner_key: :author_id,
        name: :author,
        field_options: %{
          label: "Author",
          typeahead: true,
          typeahead_limit: 5
        },
        hide_label: false,
        readonly: false,
        search_input: "",
        search_name: "resource-form_author_id_search",
        selected: {"Ada Lovelace", "selected-id"},
        selected_id: "selected-id",
        option_ids: ["selected-id"],
        options: [{"Ada Lovelace", "selected-id"}],
        prompt: "Choose an author",
        not_found_text: "No options found",
        errors: [],
        live_resource: TestTypeaheadLive,
        myself: %Phoenix.LiveComponent.CID{cid: 1}
      })

    assert html =~ ~s(type="search")
    assert html =~ ~s(name="resource-form_author_id_search")
    assert html =~ ~s(type="radio")
    assert html =~ ~s(name="change[author_id]")
    assert html =~ ~s(value="")
    refute html =~ "detached-form"
    refute html =~ "Type at least"
  end

  test "uses the child resource and nested input name inside InlineCRUD" do
    field_options = TestInlineCrudLive.fields()[:comments].child_fields[:author]
    post = %Post{id: Ash.UUID.generate(), title: "Post", comments: []}
    changeset = Ash.Changeset.for_update(post, :update, %{})
    parent_form = Phoenix.Component.to_form(changeset, as: :change)

    parent_form = %{
      parent_form
      | params: %{"comments" => [%{"author_id" => ""}]}
    }

    assert [form] =
             Phoenix.HTML.FormData.to_form(changeset, parent_form, :comments, default: [])

    assert form.options[:ash_resource] == Comment

    assigns = %{
      type: :form,
      name: :author,
      field: {:author, field_options},
      field_options: field_options,
      live_resource: TestInlineCrudLive,
      form: form
    }

    assert {:ok, socket} = BelongsTo.update(assigns, component_socket())
    assert socket.assigns.queryable == User
    assert socket.assigns.owner_key == :author_id

    html =
      render_component(
        &BelongsTo.render_form/1,
        Map.merge(socket.assigns, %{
          hide_label: false,
          readonly: false,
          myself: %Phoenix.LiveComponent.CID{cid: 1}
        })
      )

    assert html =~ ~s(name="change[comments][0][author_id]")
  end

  test "searches the display field case-insensitively and limits results" do
    alpha = seed_user!("Alpha", "alpha@example.com")
    alphabet = seed_user!("Alphabet", "alphabet@example.com")
    _alpine = seed_user!("Alpine", "alpine@example.com")
    _other = seed_user!("Other", "other@example.com")

    socket =
      :author
      |> form_assigns(TestTypeaheadLive,
        field_options: typeahead_field_options(typeahead_limit: 2)
      )
      |> update_form()
      |> search("AL")

    assert socket.assigns.options == [
             {alpha.name, alpha.id},
             {alphabet.name, alphabet.id}
           ]
  end

  test "preloads the normal relationship options up to the configured limit" do
    alpha = seed_user!("Alpha", "alpha@example.com")
    alphabet = seed_user!("Alphabet", "alphabet@example.com")
    _alpine = seed_user!("Alpine", "alpine@example.com")

    socket =
      :author
      |> form_assigns(TestTypeaheadLive,
        field_options: typeahead_field_options(typeahead_limit: 2)
      )
      |> update_form()

    assert socket.assigns.options == [
             {alpha.name, alpha.id},
             {alphabet.name, alphabet.id}
           ]
  end

  test "applies the relationship options query to search and selected records" do
    active = seed_user!("Active", "active@example.com")
    inactive = seed_user!("Inactive", "inactive@example.com", active: false)
    field_options = typeahead_field_options()

    active_socket =
      :author
      |> form_assigns(TestTypeaheadLive, value: active.id, field_options: field_options)
      |> update_form()
      |> search("active")

    assert active_socket.assigns.options == [{active.name, active.id}]
    assert active_socket.assigns.selected == {active.name, active.id}

    inactive_socket =
      :author
      |> form_assigns(TestTypeaheadLive, value: inactive.id, field_options: field_options)
      |> update_form()

    assert inactive_socket.assigns.selected == nil
  end

  test "keeps the selected option available outside the preloaded results" do
    _ahead = seed_user!("Ahead", "ahead@example.com")
    selected = seed_user!("Selected", "selected@example.com")

    socket =
      :author
      |> form_assigns(TestTypeaheadLive,
        value: selected.id,
        field_options: typeahead_field_options(typeahead_limit: 1)
      )
      |> update_form()

    refute Enum.any?(socket.assigns.options, fn {_label, id} -> id == selected.id end)
    assert socket.assigns.selected == {selected.name, selected.id}
  end

  test "uses the derived Ash relationship query for authorization" do
    actor = seed_user!("Actor", "actor@example.com")
    other_actor = seed_user!("Other actor", "other-actor@example.com")
    own_post = seed_post!("Matching own post", actor)
    _other_post = seed_post!("Matching other post", other_actor)

    socket =
      :post
      |> form_assigns(TestTypeaheadCommentLive, current_user: actor)
      |> update_form()
      |> search("Matching")

    assert socket.assigns.options == [{own_post.title, own_post.id}]
  end

  @doc false
  def translate({message, bindings}) do
    Enum.reduce(bindings, message, fn {key, value}, translated ->
      String.replace(translated, "%{#{key}}", to_string(value))
    end)
  end

  defp component_socket do
    %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
  end

  defp form_assigns(name, live_resource, opts) do
    schema = live_resource.adapter_config(:schema)
    %{owner_key: owner_key} = schema.__schema__(:association, name)

    field_options =
      Keyword.get(opts, :field_options, validated_field_options(live_resource, name))

    value = Keyword.get(opts, :value, "")

    %{
      type: :form,
      name: name,
      field: {name, field_options},
      field_options: field_options,
      live_resource: live_resource,
      form: Phoenix.Component.to_form(%{to_string(owner_key) => value}, as: :change)
    }
    |> Map.merge(Map.new(Keyword.drop(opts, [:field_options, :value])))
  end

  defp update_form(assigns) do
    assert {:ok, socket} = BelongsTo.update(assigns, component_socket())
    socket
  end

  defp search(socket, search_input) do
    params = %{socket.assigns.search_name => search_input}
    assert {:noreply, socket} = BelongsTo.handle_event("search", params, socket)
    socket
  end

  defp validated_field_options(live_resource, name) do
    Backpex.LiveResource.fields(live_resource, :edit, %{})[name]
  end

  defp typeahead_field_options(overrides \\ []) do
    TestTypeaheadLive
    |> validated_field_options(:author)
    |> Map.merge(%{
      typeahead_limit: Keyword.get(overrides, :typeahead_limit, 5),
      options_query: fn query, _assigns ->
        query
        |> where([user], user.active == true)
        |> order_by([user], asc: user.name)
      end
    })
  end

  defp seed_user!(name, email, opts \\ []) do
    Ash.Seed.seed!(%User{
      name: name,
      email: email,
      active: Keyword.get(opts, :active, true)
    })
  end

  defp seed_post!(title, actor) do
    Ash.Seed.seed!(%Post{
      title: title,
      author_id: actor.id,
      published: true
    })
  end
end
