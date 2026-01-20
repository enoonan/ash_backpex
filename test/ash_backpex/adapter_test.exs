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

    test "filter with module-based Boolean filter applies to_ash_expr/3" do
      user = user()
      published_post = post(actor: user, published: true)
      _unpublished_post = post(actor: user, published: false)

      assigns = %{current_user: user}

      # Filter with module key triggers to_ash_expr/3 callback
      filter = %{field: :published, value: ["true"], module: AshBackpex.Filters.Boolean}

      assert {:ok, 1} == Adapter.count([filters: [filter]], [], assigns, TestPostLive)
      {:ok, [post]} = Adapter.list([filters: [filter]], [], assigns, TestPostLive)
      assert post.id == published_post.id
    end

    test "filter with module-based Boolean filter returns false records" do
      user = user()
      _published_post = post(actor: user, published: true)
      unpublished_post = post(actor: user, published: false)

      assigns = %{current_user: user}

      filter = %{field: :published, value: ["false"], module: AshBackpex.Filters.Boolean}

      assert {:ok, 1} == Adapter.count([filters: [filter]], [], assigns, TestPostLive)
      {:ok, [post]} = Adapter.list([filters: [filter]], [], assigns, TestPostLive)
      assert post.id == unpublished_post.id
    end

    test "filter with module-based Boolean filter returns all when both selected" do
      user = user()
      _published_post = post(actor: user, published: true)
      _unpublished_post = post(actor: user, published: false)

      assigns = %{current_user: user}

      # Both selected means no filter applied - should return all
      filter = %{field: :published, value: ["true", "false"], module: AshBackpex.Filters.Boolean}

      assert {:ok, 2} == Adapter.count([filters: [filter]], [], assigns, TestPostLive)
      {:ok, posts} = Adapter.list([filters: [filter]], [], assigns, TestPostLive)
      assert length(posts) == 2
    end

    test "filter with module-based Select filter applies to_ash_expr/3" do
      user = user()
      draft_post = post(actor: user, status: :draft)
      _published_post = post(actor: user, status: :published)
      _archived_post = post(actor: user, status: :archived)

      assigns = %{current_user: user}

      filter = %{field: :status, value: :draft, module: AshBackpex.Filters.Select}

      assert {:ok, 1} == Adapter.count([filters: [filter]], [], assigns, TestPostLive)
      {:ok, [post]} = Adapter.list([filters: [filter]], [], assigns, TestPostLive)
      assert post.id == draft_post.id
    end

    test "multiple module-based filters combine correctly" do
      user = user()
      # Create posts with different combinations
      matching_post = post(actor: user, published: true, status: :published)
      _wrong_published = post(actor: user, published: false, status: :published)
      _wrong_status = post(actor: user, published: true, status: :draft)
      _wrong_both = post(actor: user, published: false, status: :archived)

      assigns = %{current_user: user}

      filters = [
        %{field: :published, value: ["true"], module: AshBackpex.Filters.Boolean},
        %{field: :status, value: :published, module: AshBackpex.Filters.Select}
      ]

      assert {:ok, 1} == Adapter.count([filters: filters], [], assigns, TestPostLive)
      {:ok, [post]} = Adapter.list([filters: filters], [], assigns, TestPostLive)
      assert post.id == matching_post.id
    end

    test "module filter returning nil applies no filter" do
      user = user()
      _post1 = post(actor: user, published: true)
      _post2 = post(actor: user, published: false)

      assigns = %{current_user: user}

      # Empty list value causes Boolean filter to return nil
      filter = %{field: :published, value: [], module: AshBackpex.Filters.Boolean}

      assert {:ok, 2} == Adapter.count([filters: [filter]], [], assigns, TestPostLive)
      {:ok, posts} = Adapter.list([filters: [filter]], [], assigns, TestPostLive)
      assert length(posts) == 2
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
