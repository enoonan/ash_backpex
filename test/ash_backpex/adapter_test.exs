defmodule AshBackpex.AdapterTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias AshBackpex.TestDomain.Post
  use AshBackpex.DataCase
  import TestGenerators
  alias AshBackpex.Adapter

  describe "AshBackPex.Adapter get :: it can" do
    test "get/4 returns {:ok, nil} when item not found" do
      user = user()
      assigns = %{current_user: user}
      no_match_id = Ash.UUIDv7.generate()
      assert {:ok, nil} = Adapter.get(no_match_id, [], assigns, TestPostLive)
    end

    test "get/4 returns {:ok, item} when item found" do
      user = user()
      assigns = %{current_user: user}
      post = post(actor: user, view_count: 0)

      assert {:ok, post} = Adapter.get(post.id, [], assigns, TestPostLive)
      assert post |> is_struct(Post)
    end
  end

  describe "AshBackpex.Adapter filtering :: it can" do
    test "filter list/4 and count/4" do
      user = user()
      post0 = post(actor: user, view_count: 0)
      post1 = post(actor: user, view_count: 1)
      _post2 = post(actor: user, view_count: 2)

      assigns = %{current_user: user}

      map_style_filter = %{field: :view_count, value: 0}
      assert {:ok, 1} == Adapter.count([filters: [map_style_filter]], [], assigns, TestPostLive)
      {:ok, [p0]} = Adapter.list([filters: [map_style_filter]], [], assigns, TestPostLive)
      assert(p0.id == post0.id)

      kw_style_filter = [view_count: 1]
      assert {:ok, 1} == Adapter.count([filters: kw_style_filter], [], assigns, TestPostLive)
      {:ok, [p1]} = Adapter.list([filters: kw_style_filter], [], assigns, TestPostLive)
      assert p1.id == post1.id

      require Ash.Expr

      expr_filter = Ash.Expr.expr(view_count > 0)
      assert {:ok, 2} == Adapter.count([filters: [expr_filter]], [], assigns, TestPostLive)
      {:ok, posts} = Adapter.list([filters: [expr_filter]], [], assigns, TestPostLive)
      assert posts |> length == 2
      refute Enum.any?(posts, &(&1.view_count < 1))
    end

    test "sort list/4" do
      user = user()
      post0 = post(actor: user, view_count: 0)
      post1 = post(actor: user, view_count: 0)
      default_sorted = Enum.sort([post0, post1], &(&1.id <= &2.id)) |> Enum.map(& &1.id)
      assigns = %{current_user: user}

      {:ok, posts} = Adapter.list([], [], assigns, TestPostLive)
      assert posts |> Enum.map(& &1.id) === default_sorted

      inserted_at_desc = [post1.id, post0.id]

      params = %{"order_by" => "inserted_at", "order_direction" => "desc"}

      {:ok, posts} = Adapter.list([], [], Map.put(assigns, :params, params), TestPostLive)
      assert posts |> Enum.map(& &1.id) === inserted_at_desc

      params = Map.put(params, "order_direction", "asc")
      inserted_at_asc = inserted_at_desc |> Enum.reverse()
      {:ok, posts} = Adapter.list([], [], Map.put(assigns, :params, params), TestPostLive)
      assert posts |> Enum.map(& &1.id) === inserted_at_asc
    end
  end
end
