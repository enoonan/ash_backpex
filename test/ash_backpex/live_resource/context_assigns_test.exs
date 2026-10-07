defmodule AshBackpex.LiveResource.ContextAssignsTest do
  use ExUnit.Case, async: true
  use AshBackpex.DataCase
  import TestGenerators

  alias AshBackpex.LiveResource.Info

  describe "generated config" do
    test "defaults to :all and passes :all through" do
      assert TestMinimalLive.config(:context_assigns) == :all
      assert TestContextAssignsAllLive.config(:context_assigns) == :all
    end

    test "appends :current_user and :actor to a list without duplicates" do
      assert TestContextAssignsListLive.config(:context_assigns) == [
               :locale,
               :current_user,
               :actor
             ]

      assert TestContextAssignsCurrentUserLive.config(:context_assigns) == [
               :current_user,
               :locale,
               :actor
             ]
    end
  end

  describe "DSL" do
    test "the info accessor returns the configured value like backpex_persist/1" do
      assert Info.backpex_persist(TestMinimalLive) == {:ok, []}
      assert Info.backpex_persist(TestPostLive) == {:ok, [:columns, :metrics]}

      assert Info.backpex_context_assigns(TestMinimalLive) == {:ok, :all}
      assert Info.backpex_context_assigns(TestContextAssignsAllLive) == {:ok, :all}
      assert Info.backpex_context_assigns(TestContextAssignsListLive) == {:ok, [:locale]}
      assert Info.backpex_context_assigns!(TestContextAssignsListLive) == [:locale]
    end

    test "the backpex section module doc lists the option" do
      {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} =
        Code.fetch_docs(AshBackpex.LiveResource.Dsl)

      assert moduledoc =~ "- `context_assigns`"
    end

    test "rejects a string" do
      assert_raise Spark.Error.DslError, ~r/context_assigns/, fn ->
        defmodule InvalidContextAssignsStringLive do
          use AshBackpex.LiveResource

          backpex do
            resource(AshBackpex.TestDomain.User)
            layout({TestLayout, :admin})
            context_assigns("all")
          end
        end
      end
    end

    test "rejects a list containing a string" do
      assert_raise Spark.Error.DslError, ~r/context_assigns/, fn ->
        defmodule InvalidContextAssignsListLive do
          use AshBackpex.LiveResource

          backpex do
            resource(AshBackpex.TestDomain.User)
            layout({TestLayout, :admin})
            context_assigns([:locale, "current_user"])
          end
        end
      end
    end
  end

  describe "context authorization" do
    test "keeps the actor in the context of a list-configured LiveResource" do
      user = user()
      post = post(actor: user)

      assigns = %{
        live_resource: TestContextAssignsListLive,
        current_user: user,
        unlisted: :dropped
      }

      context = Backpex.LiveResource.context(assigns)

      assert context.current_user == user
      refute Map.has_key?(context, :unlisted)

      for action <- [:index, :show, :edit, :delete, :new] do
        assert TestContextAssignsListLive.can?(context, action, post)

        assert TestContextAssignsListLive.can?(context, action, post) ==
                 TestContextAssignsListLive.can?(assigns, action, post)
      end
    end

    test "authorizes the context like the full assigns for a denied actor" do
      inactive = user(active: false)
      post = post(actor: user())

      assigns = %{live_resource: TestContextAssignsListLive, current_user: inactive}
      context = Backpex.LiveResource.context(assigns)

      for action <- [:index, :show, :edit, :delete, :new] do
        refute TestContextAssignsListLive.can?(context, action, post)
        refute TestContextAssignsListLive.can?(assigns, action, post)
      end
    end
  end
end
