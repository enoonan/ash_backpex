defmodule DemoWeb.Layouts do
  use DemoWeb, :html

  attr(:flash, :map, required: true, doc: "the map of flash messages")
  attr(:fluid?, :boolean, default: true, doc: "if the content uses full width")
  attr(:current_url, :string, required: true, doc: "the current url")
  slot(:inner_block, required: true)

  def admin(assigns) do
    ~H"""
      <Backpex.HTML.Layout.app_shell fluid={@fluid?}>
        <:topbar>
          <Backpex.HTML.Layout.topbar_branding />

          <Backpex.HTML.Layout.theme_selector
            socket={@socket}
            class="mr-2"
            themes={[
              {"Light", "light"},
              {"Dark", "dark"}
            ]}
          />
        </:topbar>
        <:sidebar>
          <Backpex.HTML.Layout.sidebar_section id="blog">
            <:label>Blog</:label>
            <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate="/posts">
              <Backpex.HTML.CoreComponents.icon name="hero-document-text" class="size-5" /> Posts
            </Backpex.HTML.Layout.sidebar_item>
          </Backpex.HTML.Layout.sidebar_section>
        </:sidebar>
        <Backpex.HTML.Layout.flash_messages flash={@flash} />
        {render_slot @inner_block}
      </Backpex.HTML.Layout.app_shell>
    """
  end

  embed_templates("layouts/*")
end
