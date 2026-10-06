defmodule Demo.Blog.Post.Changes.TidyExcerpt do
  @moduledoc """
  Collapses runs of whitespace in a post's excerpt.

  It reads the excerpt whether or not the excerpt is changing, so it needs a
  record that has `excerpt` selected. The Articles index does not list
  `excerpt` as a field, and AshBackpex's `can?/3` builds an update changeset
  for every row, which runs this change. AshBackpex reads every attribute Ash
  selects by default, so the rows have it.
  """

  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :excerpt) do
      nil ->
        changeset

      excerpt ->
        tidy = excerpt |> String.split() |> Enum.join(" ")
        Ash.Changeset.force_change_attribute(changeset, :excerpt, tidy)
    end
  end
end
