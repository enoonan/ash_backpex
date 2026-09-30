defmodule AshBackpex.AuthzTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use AshBackpex.DataCase
  import TestGenerators
  alias AshBackpex.Adapter

  describe "AshBackpex.LiveResource :: it can" do
    test "authorize correctly based on relates_to_actor_via and actor_attribute_equals policies" do
      user = user()
      post = post(actor: user)

      for action <- [:index, :show, :edit, :delete, :new] do
        assert can?(user, action, post)
      end

      user2 = user(active: false)

      for action <- [:show, :edit, :index, :delete, :new] do
        refute can?(user2, action, post)
      end
    end

    defp can?(user, action, item) do
      TestPostLive.can?(%{current_user: user}, action, item)
    end
  end

  describe "AshBackpex.LiveResource :: can? with actions turned off" do
    test "create_action false and update_action false deny :new and :edit" do
      user = user()
      post = post(actor: user)
      assigns = %{current_user: user}

      refute TestCreateAndUpdateDisabledLive.can?(assigns, :new, nil)
      refute TestCreateAndUpdateDisabledLive.can?(assigns, :edit, post)
      assert TestCreateAndUpdateDisabledLive.can?(assigns, :index, nil)
      assert TestCreateAndUpdateDisabledLive.can?(assigns, :delete, post)
    end
  end

  describe "AshBackpex.LiveResource :: can? with missing actions" do
    test "returns false for :edit when update action doesn't exist" do
      refute TestReadOnlyLive.can?(%{current_user: nil}, :edit, %{})
    end

    test "returns false for :delete when destroy action doesn't exist" do
      refute TestReadOnlyLive.can?(%{current_user: nil}, :delete, %{})
    end

    test "returns true for :index and :new when read and create actions exist" do
      assert TestReadOnlyLive.can?(%{current_user: nil}, :index, %{})
      assert TestReadOnlyLive.can?(%{current_user: nil}, :new, %{})
    end
  end

  describe "AshBackpex.LiveResource :: can? with custom item actions" do
    test "returns true for unknown actions that don't exist on the resource" do
      # :promote is not an Ash action on Item, so fallback returns true
      assert TestCustomItemActionLive.can?(%{current_user: nil}, :promote, %{})
      assert TestCustomItemActionLive.can?(%{current_user: nil}, :some_unknown_action, %{})
    end

    test "checks Ash authorization when action exists on resource" do
      # :read exists on Item resource, so it checks Ash.can?
      # Item has no policies, so it should return true
      assert TestCustomItemActionLive.can?(%{current_user: nil}, :read, %{})
    end
  end

  describe "AshBackpex.Adapter :: it can" do
    test "list/3" do
      user = user()
      user2 = user()
      post = post(actor: user)

      {:ok, [p1]} = Adapter.list([], [], %{current_user: user}, TestPostLive)
      assert post.id == p1.id

      assert {:ok, []} == Adapter.list([], [], %{current_user: user2}, TestPostLive)
    end

    test "count/4" do
      user = user()
      user2 = user()
      post(actor: user)

      assert Adapter.count([], [], %{current_user: user}, TestPostLive) == {:ok, 1}
      assert Adapter.count([], [], %{current_user: user2}, TestPostLive) == {:ok, 0}
    end
  end

  describe "Backpex central authorization :: it can" do
    test "gate Backpex.Resource.delete_all/4 with the generated Ash-backed can?/3" do
      owner = user()
      post = post(actor: owner)

      assert_raise Backpex.ForbiddenError, fn ->
        Backpex.Resource.delete_all([post], %{current_user: user()}, TestPostLive)
      end

      assert {:ok, [_post]} = Ash.read(AshBackpex.TestDomain.Post, actor: owner)
    end

    test "reload item action selections through the adapter before authorizing them" do
      owner = user()
      post = post(actor: owner)
      socket = item_action_socket(owner)

      assert [%{id: id}] = Backpex.ItemAction.authorize_fresh!(socket, :delete, [post])
      assert id == post.id

      Ash.destroy!(post, actor: owner)

      assert_raise Backpex.NoResultsError, fn ->
        Backpex.ItemAction.authorize_fresh!(socket, :delete, [post])
      end
    end

    test "raise for item action selections the actor cannot read or act on" do
      owner = user()
      post = post(actor: owner)

      assert_raise Backpex.NoResultsError, fn ->
        Backpex.ItemAction.authorize_fresh!(item_action_socket(user()), :delete, [post])
      end
    end

    defp item_action_socket(user) do
      %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          current_user: user,
          live_resource: TestPostLive,
          live_action: :index
        }
      }
    end
  end

  describe "AshBackpex.Adapter mutations" do
    test "insert/2 enforces create policies from the changeset actor" do
      inactive_user = user(active: false)

      changeset =
        Ash.Changeset.for_create(
          AshBackpex.TestDomain.Post,
          :create,
          %{title: "Unauthorized", author_id: inactive_user.id},
          actor: inactive_user
        )

      assert {:error, %Ash.Changeset{}} = Adapter.insert(changeset, TestPostLive)
    end

    test "update/2 enforces update policies from the changeset actor" do
      owner = user()
      other_user = user()
      post = post(actor: owner)

      changeset =
        Ash.Changeset.for_update(post, :update, %{title: "Unauthorized"}, actor: other_user)

      assert {:error, %Ash.Changeset{}} = Adapter.update(changeset, TestPostLive)
    end
  end
end
