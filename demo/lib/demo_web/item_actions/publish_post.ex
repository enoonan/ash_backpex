defmodule DemoWeb.ItemActions.PublishPost do
  use BackpexWeb, :item_action

  @impl Backpex.ItemAction
  def icon(assigns, _item) do
    ~H"""
    <Backpex.HTML.CoreComponents.icon
      name="hero-megaphone"
      class="h-5 w-5 cursor-pointer transition duration-75 hover:scale-110 hover:text-success"
    />
    """
  end

  @impl Backpex.ItemAction
  def label(_assigns, item) do
    if item && item.status == :published, do: "Refresh publication", else: "Publish"
  end

  @impl Backpex.ItemAction
  def confirm(assigns) do
    "Publish the selected #{Backpex.__("items", assigns.live_resource)}?"
  end

  @impl Backpex.ItemAction
  def handle(socket, items, _data) do
    actor = Map.get(socket.assigns, :current_user)

    Enum.each(items, fn item ->
      item
      |> Ash.Changeset.for_update(
        :admin_update,
        %{status: :published, published: true, published_on: Date.utc_today()},
        actor: actor
      )
      |> Ash.update!()
    end)

    {:ok, Phoenix.LiveView.put_flash(socket, :info, published_message(items))}
  end

  defp published_message([_item]), do: "Published 1 post."
  defp published_message(items), do: "Published #{length(items)} posts."
end
