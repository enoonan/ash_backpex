defmodule AshBackpex.AdapterTransactionalDeleteTest do
  @moduledoc false
  use ExUnit.Case, async: false

  alias AshBackpex.Adapter
  alias AshBackpex.TransactionalTestDomain.Entry

  setup do
    # RAM-only Mnesia: no schema is created on disk.
    :ok = :mnesia.start()
    {:atomic, :ok} = :mnesia.create_table(Entry, attributes: [:_pkey, :val])

    on_exit(fn -> :mnesia.delete_table(Entry) end)
  end

  test "delete_all/2 rolls back every deletion when one record cannot be deleted" do
    # More records than one Ash bulk batch (100), with the failing record last:
    # batch-level transactions alone would keep the first batch deleted.
    entries =
      for n <- 1..150 do
        id = "00000000-0000-4000-8000-" <> String.pad_leading(Integer.to_string(n), 12, "0")
        Ash.Seed.seed!(%Entry{id: id, name: if(n == 150, do: "blocked", else: "entry #{n}")})
      end

    assert {:error, _errors} = Adapter.delete_all(entries, TestTransactionalEntryLive)

    remaining = Entry |> Ash.read!() |> Enum.map(& &1.id) |> Enum.sort()
    assert remaining == entries |> Enum.map(& &1.id) |> Enum.sort()
  end

  test "delete_all/2 deletes and returns every record when all can be deleted" do
    entries =
      for name <- ["first", "second"] do
        Ash.Seed.seed!(%Entry{id: Ash.UUID.generate(), name: name})
      end

    assert {:ok, deleted} = Adapter.delete_all(entries, TestTransactionalEntryLive)
    assert Enum.map(deleted, & &1.id) |> Enum.sort() == Enum.map(entries, & &1.id) |> Enum.sort()
    assert Ash.read!(Entry) == []
  end
end
