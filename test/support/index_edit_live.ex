defmodule TestIndexEditLayout do
  @moduledoc false
  use Phoenix.Component

  # Backpex passes the page to the layout as the inner block slot, which
  # `TestLayout.admin/1` does not render, so a mounted index needs this layout.
  def admin(assigns) do
    ~H"""
    <div>{render_slot(@inner_block)}</div>
    """
  end
end

defmodule TestAssignmentIndexEditLive do
  @moduledoc false
  use AshBackpex.LiveResource

  backpex do
    resource AshBackpex.TestDomain.Assignment
    layout({TestIndexEditLayout, :admin})
    pubsub(server: AshBackpex.TestPubSub)

    fields do
      field :title

      field :owner do
        display_field(:name)
        typeahead(true)
        index_editable(true)
      end

      field :reviewer do
        display_field(:name)
        index_editable(true)
      end
    end
  end
end
