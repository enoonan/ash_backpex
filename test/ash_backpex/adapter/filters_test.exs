defmodule AshBackpex.Adapter.FiltersTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use AshBackpex.DataCase
  import TestGenerators
  alias AshBackpex.Adapter

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
  end
end
