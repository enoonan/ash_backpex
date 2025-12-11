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
end
