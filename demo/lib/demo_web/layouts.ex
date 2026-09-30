defmodule DemoWeb.Layouts do
  use DemoWeb, :html

  attr(:flash, :map, required: true, doc: "the map of flash messages")
  attr(:fluid?, :boolean, default: true, doc: "if the content uses full width")
  attr(:current_url, :string, required: true, doc: "the current url")
  attr(:socket, :any, required: true, doc: "the LiveView socket")
  attr(:current_theme, :string, required: true, doc: "the selected Backpex theme")
  attr(:sidebar_open, :boolean, required: true, doc: "whether the Backpex sidebar is open")

  attr(:sidebar_section_states, :map,
    required: true,
    doc: "the persisted open state of each Backpex sidebar section"
  )

  attr(:preferences_manifest, :map,
    required: true,
    doc: "the Backpex preference adapter routing manifest"
  )

  slot(:inner_block, required: true)

  def admin(assigns) do
    ~H"""
      <Backpex.HTML.Layout.app_shell
        socket={@socket}
        fluid={@fluid?}
        sidebar_open={assigns[:sidebar_open]}
        preferences_manifest={assigns[:preferences_manifest]}
      >
        <:sidebar_branding>
          <Backpex.HTML.Layout.sidebar_branding title="AshBackpex" />
        </:sidebar_branding>
        <:topbar>
          <Backpex.HTML.Layout.theme_selector
            class="ml-auto mr-2"
            current_theme={@current_theme}
            themes={[
              {"Light", "light"},
              {"Dark", "dark"}
            ]}
          />
        </:topbar>
        <:sidebar>
          <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate="/">
            <Backpex.HTML.CoreComponents.icon name="hero-home" class="size-5" /> Dashboard
          </Backpex.HTML.Layout.sidebar_item>
          <Backpex.HTML.Layout.sidebar_section
            id="blog"
            sidebar_section_states={@sidebar_section_states}
          >
            <:label>Blog</:label>
            <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate="/authors">
              <Backpex.HTML.CoreComponents.icon name="hero-users" class="size-5" /> Authors
            </Backpex.HTML.Layout.sidebar_item>
            <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate="/posts">
              <Backpex.HTML.CoreComponents.icon name="hero-document-text" class="size-5" /> Posts
            </Backpex.HTML.Layout.sidebar_item>
            <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate="/tags">
              <Backpex.HTML.CoreComponents.icon name="hero-tag" class="size-5" /> Tags
            </Backpex.HTML.Layout.sidebar_item>
            <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate="/comments">
              <Backpex.HTML.CoreComponents.icon name="hero-chat-bubble-left-right" class="size-5" /> Comments
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
