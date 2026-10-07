defmodule AshBackpex.Fields.BelongsToIndexEditTest do
  use AshBackpex.DataCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias AshBackpex.TestDomain.{Assignment, User}

  @endpoint AshBackpex.TestEndpoint

  setup_all do
    start_supervised!({Phoenix.PubSub, name: AshBackpex.TestPubSub})
    start_supervised!(AshBackpex.TestEndpoint)
    :ok
  end

  setup do
    ada = seed_user!("Ada", true)
    grace = seed_user!("Grace", true)
    inactive = seed_user!("Inactive Ian", false)

    assignment =
      Assignment
      |> Ash.Changeset.for_create(:create, %{
        title: "Review the upgrade",
        owner_id: ada.id,
        reviewer_id: ada.id
      })
      |> Ash.create!(authorize?: false)

    %{ada: ada, grace: grace, inactive: inactive, assignment: assignment}
  end

  test "AshBackpex.Fields.BelongsTo saves the index edit and no longer handles update-field" do
    assert TestAssignmentIndexEditLive.fields()[:owner].module == AshBackpex.Fields.BelongsTo
    assert function_exported?(AshBackpex.Fields.BelongsTo, :index_editable_change, 3)

    assert_raise FunctionClauseError, fn ->
      AshBackpex.Fields.BelongsTo.handle_event(
        "update-field",
        %{"index_form" => %{"value" => ""}},
        %Phoenix.LiveView.Socket{}
      )
    end
  end

  describe "typeahead belongs_to field" do
    test "saves another allowed user and re-renders the row", %{
      ada: ada,
      grace: grace,
      assignment: assignment
    } do
      view = index_view(ada)

      log =
        capture_log(fn ->
          view |> index_form(:owner, assignment) |> render_change(index_form: %{value: grace.id})
        end)

      refute log =~ "does not save the inline edit"
      assert reload!(assignment).owner_id == grace.id
      assert selected?(view, :owner, assignment, grace)
      refute invalid?(view, :owner, assignment)
    end

    test "refuses a user the relationship filter excludes", %{
      ada: ada,
      inactive: inactive,
      assignment: assignment
    } do
      view = index_view(ada)

      view |> index_form(:owner, assignment) |> render_change(index_form: %{value: inactive.id})

      assert reload!(assignment).owner_id == ada.id
      assert invalid?(view, :owner, assignment)
    end

    test "refuses an id that does not exist", %{ada: ada, assignment: assignment} do
      view = index_view(ada)

      view
      |> index_form(:owner, assignment)
      |> render_change(index_form: %{value: Ash.UUID.generate()})

      assert reload!(assignment).owner_id == ada.id
      assert invalid?(view, :owner, assignment)
    end

    test "refuses an edit by a user who may not update the record", %{
      grace: grace,
      inactive: inactive,
      assignment: assignment
    } do
      view = index_view(inactive)

      view |> index_form(:owner, assignment) |> render_change(index_form: %{value: grace.id})

      assert reload!(assignment).owner_id != grace.id
      assert invalid?(view, :owner, assignment)
    end
  end

  describe "plain belongs_to field" do
    test "saves another user and re-renders the row", %{
      ada: ada,
      grace: grace,
      assignment: assignment
    } do
      assert TestAssignmentIndexEditLive.fields()[:reviewer].module == Backpex.Fields.BelongsTo

      view = index_view(ada)

      log =
        capture_log(fn ->
          view
          |> index_form(:reviewer, assignment)
          |> render_change(index_form: %{value: grace.id})
        end)

      refute log =~ "does not save the inline edit"
      assert reload!(assignment).reviewer_id == grace.id
      assert selected?(view, :reviewer, assignment, grace)
      refute invalid?(view, :reviewer, assignment)
    end

    test "refuses an id that does not exist", %{ada: ada, assignment: assignment} do
      view = index_view(ada)

      view
      |> index_form(:reviewer, assignment)
      |> render_change(index_form: %{value: Ash.UUID.generate()})

      assert reload!(assignment).reviewer_id == ada.id
      assert invalid?(view, :reviewer, assignment)
    end

    test "refuses an edit by a user who may not update the record", %{
      grace: grace,
      inactive: inactive,
      assignment: assignment
    } do
      view = index_view(inactive)

      view
      |> index_form(:reviewer, assignment)
      |> render_change(index_form: %{value: grace.id})

      assert reload!(assignment).reviewer_id != grace.id
      assert invalid?(view, :reviewer, assignment)
    end
  end

  defp index_view(current_user) do
    {:ok, view, _html} =
      build_conn()
      |> Plug.Test.init_test_session(%{"current_user_id" => current_user.id})
      |> live("/assignments")

    view
  end

  defp index_form(view, name, assignment), do: form(view, "#index-form-#{name}-#{assignment.id}")

  defp selected?(view, name, assignment, user) do
    has_element?(
      view,
      "#index-form-input-#{name}-#{assignment.id} option[selected][value='#{user.id}']",
      user.name
    )
  end

  defp invalid?(view, name, assignment) do
    has_element?(view, "#index-form-input-#{name}-#{assignment.id}.select-error")
  end

  defp reload!(assignment), do: Ash.get!(Assignment, assignment.id, authorize?: false)

  defp seed_user!(name, active) do
    User
    |> Ash.Changeset.for_create(:create, %{
      name: name,
      email: "#{String.downcase(name)}@example.com",
      active: active
    })
    |> Ash.create!()
  end
end
