defmodule AshBackpex.Fields.BelongsTo do
  @moduledoc """
  A server-backed typeahead form for `belongs_to` relationships.

  AshBackpex selects this field automatically when a `belongs_to` field enables
  `typeahead`. Index and show rendering continue to use Backpex's standard
  `BelongsTo` implementation.
  """

  @config_schema Backpex.Fields.BelongsTo.config_schema() ++
                   [
                     typeahead: [
                       doc: "Use the server-backed typeahead form.",
                       type: :boolean,
                       default: true
                     ],
                     typeahead_limit: [
                       doc: "Maximum number of matching options returned by a search.",
                       type: :pos_integer,
                       default: 10
                     ]
                   ]

  use Backpex.Field, config_schema: @config_schema

  import Ecto.Query

  alias Backpex.HTML.Form, as: BackpexForm

  require Backpex

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    %{name: name, field: field} = assigns
    schema = assigns.live_resource.adapter_config(:schema)

    %{
      queryable: queryable,
      owner_key: owner_key,
      related_key: related_key
    } = schema.__schema__(:association, name)

    display_field = display_field(field)
    display_field_form = Map.get(assigns.field_options, :display_field_form, display_field)

    socket
    |> assign(assigns)
    |> assign(:queryable, queryable)
    |> assign(:owner_key, owner_key)
    |> assign(:related_key, related_key)
    |> assign(:display_field, display_field)
    |> assign(:display_field_form, display_field_form)
    |> apply_action(assigns.type)
    |> ok()
  end

  defp apply_action(socket, :form) do
    %{assigns: %{field_options: field_options} = assigns} = socket

    socket
    |> assign_new(:prompt, fn -> prompt(assigns, field_options) end)
    |> assign_new(:not_found_text, fn ->
      Backpex.__("No options found", socket.assigns.live_resource)
    end)
    |> assign_new(:search_input, fn -> "" end)
    |> assign_initial_options()
    |> assign_selected()
    |> assign_form_errors()
  end

  defp apply_action(socket, _type), do: socket

  @impl Backpex.Field
  defdelegate render_value(assigns), to: Backpex.Fields.BelongsTo

  @impl Backpex.Field
  def render_form(assigns) do
    assigns = assign(assigns, :help_text, Backpex.Field.help_text(assigns.field_options, assigns))

    ~H"""
    <div id={"belongs-to-typeahead-#{@name}"}>
      <Layout.field_container>
        <:label :if={not @hide_label} align={Backpex.Field.align_label(@field_options, assigns)}>
          <Layout.input_label as="span" text={@field_options[:label]} />
        </:label>

        <Backpex.HTML.CoreComponents.dropdown
          id={"belongs-to-typeahead-dropdown-#{@name}"}
          class="w-full"
        >
          <:trigger
            aria_labelledby={Map.get(assigns, :aria_labelledby)}
            class={[
              "input block h-fit w-full p-2",
              @errors == [] && "bg-transparent",
              @errors != [] && "input-error bg-error/10"
            ]}
          >
            <div class="flex h-full w-full flex-wrap items-center gap-1 px-2">
              <p :if={is_nil(@selected)} class="p-0.5 text-sm">
                {@prompt || Backpex.__("Select option", @live_resource)}
              </p>
              <div
                :if={@selected}
                class="badge badge-sm badge-soft badge-primary pointer-events-auto pr-0"
              >
                <span>{elem(@selected, 0)}</span>
                <div
                  :if={@prompt && not @readonly}
                  class="flex cursor-pointer items-center pr-2"
                  role="button"
                  phx-click="clear"
                  phx-target={@myself}
                  aria-label={Backpex.__("Clear selection", @live_resource)}
                >
                  <Backpex.HTML.CoreComponents.icon
                    name="hero-x-mark"
                    class="size-4 scale-105 hover:scale-110"
                  />
                </div>
              </div>
            </div>
          </:trigger>

          <:menu class="w-full overflow-y-auto">
            <div class="max-h-72 p-2">
              <input
                type="search"
                name={"#{@name}_search"}
                class="input input-sm mb-2 w-full"
                placeholder={Backpex.__("Search", @live_resource)}
                value={@search_input}
                disabled={@readonly}
                phx-change="search"
                phx-target={@myself}
                phx-debounce={Backpex.Field.debounce(@field_options, assigns)}
              />

              <p :if={@options == []} class="mt-2 w-full">{@not_found_text}</p>

              <input
                type="hidden"
                name={@form[@owner_key].name}
                value=""
                disabled={@readonly}
                tabindex="-1"
                aria-hidden="true"
              />

              <input
                :if={@selected_id && normalized_id(@selected_id) not in @option_ids}
                type="radio"
                name={@form[@owner_key].name}
                value={@selected_id}
                class="hidden"
                checked
                disabled={@readonly}
                tabindex="-1"
                aria-hidden="true"
              />

              <div class="my-2 w-full">
                <label
                  :for={{label, value} <- @options}
                  class="mt-2 flex cursor-pointer items-center gap-x-2"
                  phx-click="select"
                  phx-value-id={value}
                  phx-target={@myself}
                >
                  <input
                    type="radio"
                    name={@form[@owner_key].name}
                    value={value}
                    checked={same_value?(@selected_id, value)}
                    disabled={@readonly}
                    class="radio radio-sm radio-primary"
                  />
                  <span class="label-text">{label}</span>
                </label>
              </div>
            </div>
          </:menu>
        </Backpex.HTML.CoreComponents.dropdown>

        <BackpexForm.error :for={msg <- @errors} class="mt-1">{msg}</BackpexForm.error>

        <BackpexForm.help_text :if={@help_text} class="mt-1">
          {@help_text}
        </BackpexForm.help_text>
      </Layout.field_container>
    </div>
    """
  end

  @impl Backpex.Field
  defdelegate render_index_form(assigns), to: Backpex.Fields.BelongsTo

  @impl Backpex.Field
  defdelegate display_field(field), to: Backpex.Fields.BelongsTo

  @impl Backpex.Field
  defdelegate schema(field, schema), to: Backpex.Fields.BelongsTo

  @impl Backpex.Field
  defdelegate association?(field), to: Backpex.Fields.BelongsTo

  @impl Phoenix.LiveComponent
  def handle_event("search", params, socket) do
    search_input = Map.get(params, "#{socket.assigns.name}_search", "")

    socket
    |> assign(:search_input, search_input)
    |> assign_options()
    |> noreply()
  end

  def handle_event("select", %{"id" => id}, socket) do
    socket
    |> select_option(id)
    |> noreply()
  end

  def handle_event("clear", _params, socket) do
    socket
    |> assign(:selected_id, nil)
    |> assign(:selected, nil)
    |> reset_search()
    |> noreply()
  end

  def handle_event("update-field", %{"index_form" => %{"value" => value}}, socket) do
    Backpex.Field.handle_index_editable(socket, value, %{socket.assigns.owner_key => value})
  end

  defp options(assigns, search_input) do
    search_input = String.trim(search_input)

    assigns.queryable
    |> from()
    |> maybe_options_query(assigns.field_options, assigns)
    |> maybe_search_query(assigns.display_field, search_input)
    |> limit(^assigns.field_options.typeahead_limit)
    |> assigns.live_resource.adapter_config(:repo).all()
    |> Enum.map(&option(&1, assigns))
  end

  defp assign_options(socket) do
    options = options(socket.assigns, socket.assigns.search_input)

    socket
    |> assign(:options, options)
    |> assign(:option_ids, Enum.map(options, fn {_label, value} -> normalized_id(value) end))
  end

  defp assign_initial_options(%{assigns: %{options: _options}} = socket), do: socket
  defp assign_initial_options(socket), do: assign_options(socket)

  defp assign_selected(socket) do
    selected_id = normalize_selected_id(socket.assigns.form[socket.assigns.owner_key].value)

    selected =
      find_option(socket.assigns.options, selected_id) ||
        fetch_selected_option(socket, selected_id)

    socket
    |> assign(:selected_id, selected_id)
    |> assign(:selected, selected)
  end

  defp select_option(socket, id) do
    case find_option(socket.assigns.options, id) do
      {label, value} ->
        socket
        |> assign(:selected_id, value)
        |> assign(:selected, {label, value})
        |> reset_search()

      nil ->
        socket
    end
  end

  defp reset_search(socket) do
    socket
    |> assign(:search_input, "")
    |> assign_options()
  end

  defp maybe_options_query(query, %{options_query: options_query}, assigns),
    do: options_query.(query, assigns)

  defp maybe_options_query(query, _field_options, _assigns), do: query

  defp maybe_search_query(query, _display_field, ""), do: query

  defp maybe_search_query(query, display_field, search_input) do
    pattern = "%#{String.downcase(search_input)}%"
    where(query, [record], like(fragment("lower(?)", field(record, ^display_field)), ^pattern))
  end

  defp option(record, assigns) do
    {Map.get(record, assigns.display_field_form), Map.get(record, assigns.related_key)}
  end

  defp find_option(_options, nil), do: nil

  defp find_option(options, selected_id) do
    Enum.find(options, fn {_label, value} -> same_value?(value, selected_id) end)
  end

  defp fetch_selected_option(_socket, nil), do: nil

  defp fetch_selected_option(socket, selected_id) do
    socket.assigns.queryable
    |> from()
    |> maybe_options_query(socket.assigns.field_options, socket.assigns)
    |> where([record], field(record, ^socket.assigns.related_key) == ^selected_id)
    |> limit(1)
    |> socket.assigns.live_resource.adapter_config(:repo).one()
    |> case do
      nil -> nil
      record -> option(record, socket.assigns)
    end
  end

  defp prompt(assigns, field_options) do
    case Map.get(field_options, :prompt) do
      nil -> nil
      prompt when is_function(prompt, 1) -> prompt.(assigns)
      prompt -> prompt
    end
  end

  defp assign_form_errors(socket) do
    %{assigns: %{form: form, owner_key: owner_key, field_options: field_options} = assigns} =
      socket

    errors =
      if Phoenix.Component.used_input?(form[owner_key]), do: form[owner_key].errors, else: []

    assign(
      socket,
      :errors,
      BackpexForm.translate_form_errors(
        errors,
        Backpex.Field.translate_error_fun(field_options, assigns)
      )
    )
  end

  defp normalize_selected_id(value) when value in [nil, ""], do: nil
  defp normalize_selected_id(value), do: value

  defp normalized_id(value), do: to_string(value)

  defp same_value?(nil, nil), do: true
  defp same_value?(nil, _value), do: false
  defp same_value?(_value, nil), do: false
  defp same_value?(left, right), do: to_string(left) == to_string(right)
end
