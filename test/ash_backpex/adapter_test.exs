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

  describe "AshBackpex.Adapter delete_all :: it can" do
    test "delete_all/2 uses the LiveResource's configured destroy action" do
      item = Ash.Seed.seed!(%AshBackpex.TestDomain.Item{name: "Keep me"})

      assert {:ok, [%{id: id}]} = Adapter.delete_all([item], TestSoftDeleteItemLive)
      assert id == item.id

      assert %{note: "soft deleted"} = Ash.get!(AshBackpex.TestDomain.Item, item.id)
    end

    test "delete_all/2 returns every deleted record for a multi-item selection" do
      items =
        for name <- ["First", "Second", "Third"] do
          Ash.Seed.seed!(%AshBackpex.TestDomain.Item{name: name})
        end

      assert {:ok, deleted} = Adapter.delete_all(items, TestItemLive)

      assert deleted |> Enum.map(& &1.id) |> Enum.sort() ==
               items |> Enum.map(& &1.id) |> Enum.sort()

      assert {:ok, []} = Ash.read(AshBackpex.TestDomain.Item)
    end

    test "delete_all/2 returns an error when a record cannot be deleted" do
      owner = user()
      referenced_post = post(actor: owner)

      Ash.Seed.seed!(%AshBackpex.TestDomain.Comment{
        body: "Keeps the post referenced",
        post_id: referenced_post.id,
        author_id: owner.id
      })

      # AshSqlite cannot run transactions, so all-or-nothing deletion is covered in
      # adapter_transactional_delete_test.exs against a transactional data layer.
      assert {:error, _error} = Adapter.delete_all([referenced_post], TestPostLive)

      assert [%{id: id}] = Ash.read!(Post, authorize?: false)
      assert id == referenced_post.id
    end

    test "delete_all/2 falls back to the resource's primary destroy action" do
      item = Ash.Seed.seed!(%AshBackpex.TestDomain.Item{name: "Delete me"})

      assert {:ok, [_item]} = Adapter.delete_all([item], TestItemLive)

      assert {:error, %Ash.Error.Invalid{}} = Ash.get(AshBackpex.TestDomain.Item, item.id)
    end
  end

  describe "AshBackpex.Adapter change :: it can" do
    test "build update changesets for index-editable fields without a form assign" do
      user = user()
      post = post(actor: user)

      changeset =
        Adapter.change(
          post,
          %{title: "Updated title"},
          TestPostLive.fields(),
          %{current_user: user, live_resource: TestPostLive},
          TestPostLive,
          action: :update
        )

      assert %Ash.Changeset{action_type: :update, data: ^post} = changeset
    end

    test "removes blank form values from has_many, multiselect, and checkgroup list fields" do
      user = user()
      post = post(actor: user)

      fields = [
        comments: %{module: Backpex.Fields.HasMany},
        tags: %{module: Backpex.Fields.MultiSelect},
        roles: %{module: Backpex.Fields.Checkgroup},
        keywords: %{module: Backpex.Fields.Text}
      ]

      Adapter.change(
        post,
        %{
          "comments" => [""],
          "tags" => ["", "food", "politics"],
          "roles" => ["", "admin"],
          "keywords" => ["", "keep-me"],
          atom_tags: ["", "keep-me-too"]
        },
        fields,
        %{current_user: user, live_resource: TestParamCaptureLive, test_pid: self()},
        TestParamCaptureLive,
        action: :update
      )

      assert_receive {:captured_params,
                      %{
                        "comments" => [],
                        "tags" => ["food", "politics"],
                        "roles" => ["admin"],
                        "keywords" => ["", "keep-me"],
                        atom_tags: ["", "keep-me-too"]
                      }}
    end

    test "normalizes InlineCRUD add, delete, and order params for manage_relationship" do
      user = user()
      post = post(actor: user)

      fields = [
        comments: %{module: Backpex.Fields.InlineCRUD}
      ]

      Adapter.change(
        post,
        %{
          "comments" => %{
            "0" => %{
              "id" => "first-id",
              "body" => "First",
              "_persistent_id" => "0"
            },
            "1" => %{
              "id" => "second-id",
              "body" => "Second",
              "_persistent_id" => "1"
            }
          },
          "comments_order" => ["1", "0", "new"],
          "comments_delete" => ["", "0"]
        },
        fields,
        %{current_user: user, live_resource: TestParamCaptureLive, test_pid: self()},
        TestParamCaptureLive,
        action: :update
      )

      assert_receive {:captured_params, captured_params}

      assert captured_params == %{
               "comments" => [
                 %{"id" => "second-id", "body" => "Second", "_persistent_id" => "1"},
                 %{}
               ]
             }
    end

    test "moves InlineCRUD entries up and down" do
      user = user()
      post = post(actor: user)
      fields = [comments: %{module: AshBackpex.Fields.InlineCRUD}]

      entries = %{
        "0" => %{"body" => "First", "_persistent_id" => "first"},
        "1" => %{"body" => "Second", "_persistent_id" => "second"},
        "2" => %{"body" => "Third", "_persistent_id" => "third"}
      }

      for {move, index, expected} <- [
            {"comments_move_up", "2",
             [{"First", "first"}, {"Third", "third"}, {"Second", "second"}]},
            {"comments_move_down", "0",
             [{"Second", "second"}, {"First", "first"}, {"Third", "third"}]}
          ] do
        Adapter.change(
          post,
          %{
            "comments" => entries,
            "comments_order" => ["0", "1", "2"],
            move => [index]
          },
          fields,
          %{current_user: user, live_resource: TestParamCaptureLive, test_pid: self()},
          TestParamCaptureLive,
          action: :update
        )

        assert_receive {:captured_params, %{"comments" => comments}}
        assert Enum.map(comments, &{&1["body"], &1["_persistent_id"]}) == expected
      end
    end

    test "leaves an InlineCRUD relationship absent when it was not submitted" do
      user = user()
      post = post(actor: user)

      Adapter.change(
        post,
        %{"title" => "Updated"},
        [comments: %{module: Backpex.Fields.InlineCRUD}],
        %{current_user: user, live_resource: TestParamCaptureLive, test_pid: self()},
        TestParamCaptureLive,
        action: :update
      )

      assert_receive {:captured_params, %{"title" => "Updated"}}
    end

    test "normalizes InlineCRUD controls independently at every repeated depth" do
      user = user()
      post = post(actor: user)

      fields = [
        sections: %{
          module: AshBackpex.Fields.InlineCRUD,
          child_fields: [
            title: %{module: Backpex.Fields.Text},
            columns: %{
              module: AshBackpex.Fields.InlineCRUD,
              child_fields: [heading: %{module: Backpex.Fields.Text}]
            }
          ]
        }
      ]

      sections = %{
        "0" => %{
          "title" => "First",
          "_persistent_id" => "section-0",
          "columns" => %{
            "0" => %{"heading" => "First column", "_persistent_id" => "column-0"},
            "1" => %{"heading" => "Second column", "_persistent_id" => "column-1"}
          },
          "columns_order" => ["0", "1"]
        },
        "1" => %{
          "title" => "Second",
          "_persistent_id" => "section-1",
          "columns" => %{
            "0" => %{"heading" => "Sibling column", "_persistent_id" => "sibling-0"}
          },
          "columns_order" => ["0"]
        }
      }

      for {name, params, expected_sections} <- [
            {"add", %{"sections_order" => ["0", "1", "new"]},
             [
               {"First", ["First column", "Second column"]},
               {"Second", ["Sibling column"]},
               {nil, []}
             ]},
            {"delete", %{"sections_order" => ["0", "1"], "sections_delete" => ["1"]},
             [{"First", ["First column", "Second column"]}]},
            {"reorder", %{"sections_order" => ["1", "0"]},
             [{"Second", ["Sibling column"]}, {"First", ["First column", "Second column"]}]},
            {"move up", %{"sections_order" => ["0", "1"], "sections_move_up" => ["1"]},
             [{"Second", ["Sibling column"]}, {"First", ["First column", "Second column"]}]},
            {"move down", %{"sections_order" => ["0", "1"], "sections_move_down" => ["0"]},
             [{"Second", ["Sibling column"]}, {"First", ["First column", "Second column"]}]}
          ] do
        Adapter.change(
          post,
          Map.merge(%{"sections" => sections}, params),
          fields,
          %{current_user: user, live_resource: TestParamCaptureLive, test_pid: self()},
          TestParamCaptureLive,
          action: :update
        )

        assert_receive {:captured_params, %{"sections" => captured_sections}},
                       100,
                       "#{name} control was not captured"

        assert Enum.map(captured_sections, fn section ->
                 {section["title"], Enum.map(section["columns"] || [], & &1["heading"])}
               end) == expected_sections
      end

      for {name, params, expected_columns} <- [
            {"add", put_in(sections, ["0", "columns_order"], ["0", "1", "new"]),
             ["First column", "Second column", nil]},
            {"delete", put_in(sections, ["0", "columns_delete"], ["0"]), ["Second column"]},
            {"reorder", put_in(sections, ["0", "columns_order"], ["1", "0"]),
             ["Second column", "First column"]},
            {"move up", put_in(sections, ["0", "columns_move_up"], ["1"]),
             ["Second column", "First column"]},
            {"move down", put_in(sections, ["0", "columns_move_down"], ["0"]),
             ["Second column", "First column"]}
          ] do
        Adapter.change(
          post,
          %{"sections" => params, "sections_order" => ["0", "1"]},
          fields,
          %{current_user: user, live_resource: TestParamCaptureLive, test_pid: self()},
          TestParamCaptureLive,
          action: :update
        )

        assert_receive {:captured_params, %{"sections" => [%{"columns" => columns}, sibling]}},
                       100,
                       "nested #{name} control was not captured"

        assert Enum.map(columns, & &1["heading"]) == expected_columns
        assert Enum.map(sibling["columns"], & &1["heading"]) == ["Sibling column"]
      end
    end

    test "normalizes nested InlineCRUD controls without affecting siblings or singular embeds" do
      user = user()
      post = post(actor: user)

      fields = [
        sections: %{
          module: AshBackpex.Fields.InlineCRUD,
          child_fields: [
            columns: %{
              module: AshBackpex.Fields.InlineCRUD,
              child_fields: [
                target: %{
                  module: AshBackpex.Fields.Embedded,
                  child_fields: [
                    labels: %{
                      module: AshBackpex.Fields.InlineCRUD,
                      child_fields: [value: %{module: Backpex.Fields.Text}]
                    }
                  ]
                }
              ]
            }
          ]
        }
      ]

      params = %{
        "sections" => %{
          "0" => %{
            "columns" => %{
              "0" => %{
                "target" => %{
                  "kind" => "text",
                  "labels" => %{
                    "0" => %{"value" => "one", "_persistent_id" => "label-0"},
                    "1" => %{"value" => "two", "_persistent_id" => "label-1"}
                  },
                  "labels_order" => ["0", "1"],
                  "labels_move_up" => ["1"]
                }
              },
              "1" => %{"target" => %{"kind" => "number", "labels" => []}}
            },
            "columns_order" => ["0", "1"]
          },
          "1" => %{
            "columns" => %{"0" => %{"target" => %{"kind" => "sibling", "labels" => []}}},
            "columns_order" => ["0"]
          }
        },
        "sections_order" => ["0", "1"],
        "unknown" => "preserved"
      }

      Adapter.change(
        post,
        params,
        fields,
        %{current_user: user, live_resource: TestParamCaptureLive, test_pid: self()},
        TestParamCaptureLive,
        action: :update
      )

      assert_receive {:captured_params, captured_params}
      assert captured_params["unknown"] == "preserved"
      assert [%{"columns" => columns}, %{"columns" => [sibling]}] = captured_params["sections"]

      assert [%{"target" => target}, %{"target" => %{"kind" => "number", "labels" => []}}] =
               columns

      assert target["kind"] == "text"
      assert Enum.map(target["labels"], & &1["value"]) == ["two", "one"]
      assert sibling["target"] == %{"kind" => "sibling", "labels" => []}
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

    test "filter with a Range filter keeps rows from the whole end date on a datetime field" do
      morning =
        Ash.Seed.seed!(%AshBackpex.TestDomain.Item{
          name: "Morning",
          created_at: ~U[2024-06-15 09:00:00Z]
        })

      evening =
        Ash.Seed.seed!(%AshBackpex.TestDomain.Item{
          name: "Evening",
          created_at: ~U[2024-06-15 18:30:00Z]
        })

      _next_day =
        Ash.Seed.seed!(%AshBackpex.TestDomain.Item{
          name: "Next day",
          created_at: ~U[2024-06-16 00:00:00Z]
        })

      assigns = %{current_user: nil}
      value = %{"start" => "2024-06-15", "end" => "2024-06-15"}
      filter = %{field: :created_at, value: value, module: AshBackpex.Filters.Range}

      {:ok, items} = Adapter.list([filters: [filter]], [], assigns, TestItemLive)
      assert items |> Enum.map(& &1.id) |> Enum.sort() == Enum.sort([morning.id, evening.id])
    end

    test "filter with a Range filter keeps the end date itself on a date field" do
      last_day =
        Ash.Seed.seed!(%AshBackpex.TestDomain.Item{name: "Last day", birth_date: ~D[2024-12-31]})

      _next_year =
        Ash.Seed.seed!(%AshBackpex.TestDomain.Item{name: "Next year", birth_date: ~D[2025-01-01]})

      assigns = %{current_user: nil}

      filter = %{
        field: :birth_date,
        value: %{"start" => "", "end" => "2024-12-31"},
        module: AshBackpex.Filters.Range
      }

      {:ok, items} = Adapter.list([filters: [filter]], [], assigns, TestItemLive)
      assert Enum.map(items, & &1.id) == [last_day.id]
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

    test "filter_values and filter_configs criteria from Backpex 0.18 apply filters" do
      user = user()
      published_post = post(actor: user, published: true)
      _unpublished_post = post(actor: user, published: false)

      assigns = %{current_user: user}

      criteria = [
        filter_values: %{published: ["true"]},
        filter_configs: TestPostLive.filters()
      ]

      assert {:ok, 1} == Adapter.count(criteria, [], assigns, TestPostLive)
      {:ok, [post]} = Adapter.list(criteria, [], assigns, TestPostLive)
      assert post.id == published_post.id
    end

    test "filter_values and filter_configs apply MultiSelect filters to SQLite array attributes" do
      user = user()
      food_post = post(actor: user, tags: [:food])
      entertainment_post = post(actor: user, tags: [:entertainment])
      combo_post = post(actor: user, tags: [:food, :politics])

      assigns = %{current_user: user}

      criteria = [
        filter_values: %{tags: ["food"]},
        filter_configs: TestArrayFilterTypeLive.filters()
      ]

      assert {:ok, 2} == Adapter.count(criteria, [], assigns, TestArrayFilterTypeLive)
      {:ok, posts} = Adapter.list(criteria, [], assigns, TestArrayFilterTypeLive)

      post_ids = posts |> Enum.map(& &1.id) |> MapSet.new()
      assert MapSet.member?(post_ids, food_post.id)
      assert MapSet.member?(post_ids, combo_post.id)
      refute MapSet.member?(post_ids, entertainment_post.id)
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

    test "filter with module-based Range filter - start only (>=)" do
      user = user()
      _low_post = post(actor: user, view_count: 5)
      mid_post = post(actor: user, view_count: 15)
      high_post = post(actor: user, view_count: 25)

      assigns = %{current_user: user}

      # Only start value - filters for view_count >= 10
      filter = %{
        field: :view_count,
        value: %{"start" => "10", "end" => ""},
        module: AshBackpex.Filters.Range
      }

      assert {:ok, 2} == Adapter.count([filters: [filter]], [], assigns, TestPostLive)
      {:ok, posts} = Adapter.list([filters: [filter]], [], assigns, TestPostLive)
      assert length(posts) == 2
      post_ids = Enum.map(posts, & &1.id) |> MapSet.new()
      assert MapSet.member?(post_ids, mid_post.id)
      assert MapSet.member?(post_ids, high_post.id)
    end

    test "filter with module-based Range filter - end only (<=)" do
      user = user()
      low_post = post(actor: user, view_count: 5)
      mid_post = post(actor: user, view_count: 15)
      _high_post = post(actor: user, view_count: 25)

      assigns = %{current_user: user}

      # Only end value - filters for view_count <= 20
      filter = %{
        field: :view_count,
        value: %{"start" => "", "end" => "20"},
        module: AshBackpex.Filters.Range
      }

      assert {:ok, 2} == Adapter.count([filters: [filter]], [], assigns, TestPostLive)
      {:ok, posts} = Adapter.list([filters: [filter]], [], assigns, TestPostLive)
      assert length(posts) == 2
      post_ids = Enum.map(posts, & &1.id) |> MapSet.new()
      assert MapSet.member?(post_ids, low_post.id)
      assert MapSet.member?(post_ids, mid_post.id)
    end

    test "filter with module-based Range filter - both start and end" do
      user = user()
      _low_post = post(actor: user, view_count: 5)
      mid_post = post(actor: user, view_count: 15)
      _high_post = post(actor: user, view_count: 25)

      assigns = %{current_user: user}

      # Both values - filters for 10 <= view_count <= 20
      filter = %{
        field: :view_count,
        value: %{"start" => "10", "end" => "20"},
        module: AshBackpex.Filters.Range
      }

      assert {:ok, 1} == Adapter.count([filters: [filter]], [], assigns, TestPostLive)
      {:ok, [post]} = Adapter.list([filters: [filter]], [], assigns, TestPostLive)
      assert post.id == mid_post.id
    end

    test "filter with module-based Range filter - empty values returns all" do
      user = user()
      _post1 = post(actor: user, view_count: 5)
      _post2 = post(actor: user, view_count: 15)
      _post3 = post(actor: user, view_count: 25)

      assigns = %{current_user: user}

      # Both empty - no filter applied
      filter = %{
        field: :view_count,
        value: %{"start" => "", "end" => ""},
        module: AshBackpex.Filters.Range
      }

      assert {:ok, 3} == Adapter.count([filters: [filter]], [], assigns, TestPostLive)
      {:ok, posts} = Adapter.list([filters: [filter]], [], assigns, TestPostLive)
      assert length(posts) == 3
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
