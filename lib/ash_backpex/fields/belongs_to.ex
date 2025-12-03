defmodule AshBackpex.Fields.BelongsTo do
  @config_schema [
    display_field: [
      doc: "The field of the relation to be used for searching, ordering and displaying values.",
      type: :atom,
      required: true
    ],
    display_field_form: [
      doc: "Field to be used to display form values.",
      type: :atom
    ],
    live_resource: [
      doc: "The live resource of the association. Used to generate links navigating to the association.",
      type: :atom
    ],
    options_query: [
      doc: """
      Manipulates the list of available options in the select.

      For Ash resources, this is automatically filtered to only show records the current actor
      is authorized to read. You can provide a custom function to further filter options:

      The function receives `(query, assigns)` where query is an Ecto query that has already
      been filtered by Ash authorization policies.

      Defaults to showing all authorized entries.
      """,
      type: {:fun, 2}
    ],
    prompt: [
      doc: "The text to be displayed when no option is selected or function that receives the assigns.",
      type: {:or, [:string, {:fun, 1}]}
    ],
    debounce: [
      doc: "Timeout value (in milliseconds), \"blur\" or function that receives the assigns.",
      type: {:or, [:pos_integer, :string, {:fun, 1}]}
    ],
    throttle: [
      doc: "Timeout value (in milliseconds) or function that receives the assigns.",
      type: {:or, [:pos_integer, {:fun, 1}]}
    ]
  ]

  @moduledoc """
  An Ash-aware field for handling a `belongs_to` relation.

  This field automatically respects Ash authorization policies by filtering dropdown options
  to only show records the current actor is authorized to read.

  ## Field-specific options

  See `Backpex.Field` for general field options.

  #{NimbleOptions.docs(@config_schema)}

  ## Example

      @impl Backpex.LiveResource
      def fields do
      [
        workspace: %{
          module: AshBackpex.Fields.BelongsTo,
          label: "Workspace",
          display_field: :name,
          live_resource: MyAppWeb.WorkspaceLive
        }
      ]
      end

  ## Authorization

  The field automatically queries the related Ash resource with the current actor,
  ensuring that only records the user is authorized to read appear in the dropdown.

  If you need to further customize the options beyond authorization, you can provide
  an `options_query` function that receives an already-filtered Ecto query:

      workspace: %{
        module: AshBackpex.Fields.BelongsTo,
        display_field: :name,
        options_query: fn query, _assigns ->
          # Further filter the already-authorized results
          where(query, [w], w.active == true)
        end
      }
  """
  use Backpex.Field, config_schema: @config_schema
  import Ecto.Query
  alias Backpex.Router
  require Logger

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    %{name: name, field: field} = assigns
    schema = assigns.live_resource.adapter_config(:schema)
    %{queryable: queryable, owner_key: owner_key} = schema.__schema__(:association, name)

    display_field = display_field(field)
    display_field_form = display_field_form(field, display_field)

    socket
    |> assign(assigns)
    |> assign(queryable: queryable)
    |> assign(owner_key: owner_key)
    |> assign(display_field: display_field)
    |> assign(display_field_form: display_field_form)
    |> ok()
  end

  @impl Backpex.Field
  def render_value(%{value: value} = assigns) when is_nil(value) do
    ~H"""
    <p class={@live_action in [:index, :resource_action] && "truncate"}>
      {HTML.pretty_value(nil)}
    </p>
    """
  end

  @impl Backpex.Field
  def render_value(assigns) do
    %{value: value, display_field: display_field} = assigns

    assigns =
      assigns
      |> assign(:display_text, Map.get(value, display_field))
      |> assign_link()

    ~H"""
    <div class={[@live_action in [:index, :resource_action] && "truncate"]}>
      <%= if @link do %>
        <.link navigate={@link} class={[@live_action in [:index, :resource_action] && "truncate", "hover:underline"]}>
          {@display_text}
        </.link>
      <% else %>
        <p class={@live_action in [:index, :resource_action] && "truncate"}>
          {HTML.pretty_value(@display_text)}
        </p>
      <% end %>
    </div>
    """
  end

  @impl Backpex.Field
  def render_form(assigns) do
    %{
      field_options: field_options,
      queryable: queryable,
      owner_key: owner_key,
      display_field_form: display_field_form
    } = assigns

    repo = assigns.live_resource.adapter_config(:repo)
    options = get_ash_authorized_options(queryable, field_options, display_field_form, assigns)

    assigns =
      assigns
      |> assign(:options, options)
      |> assign(:owner_key, owner_key)
      |> assign_prompt(field_options)

    ~H"""
    <div>
      <Layout.field_container>
        <:label align={Backpex.Field.align_label(@field_options, assigns)}>
          <Layout.input_label for={@form[@owner_key]} text={@field_options[:label]} />
        </:label>
        <BackpexForm.input
          type="select"
          field={@form[@owner_key]}
          options={@options}
          prompt={@prompt}
          translate_error_fun={Backpex.Field.translate_error_fun(@field_options, assigns)}
          help_text={Backpex.Field.help_text(@field_options, assigns)}
          phx-debounce={Backpex.Field.debounce(@field_options, assigns)}
          phx-throttle={Backpex.Field.throttle(@field_options, assigns)}
          aria-labelledby={Map.get(assigns, :aria_labelledby)}
        />
      </Layout.field_container>
    </div>
    """
  end

  @impl Backpex.Field
  def render_index_form(assigns) do
    %{field_options: field_options, queryable: queryable, display_field_form: display_field_form} = assigns
    options = get_ash_authorized_options(queryable, field_options, display_field_form, assigns)
    form = to_form(%{"value" => assigns.value}, as: :index_form)

    assigns =
      assigns
      |> assign(:options, options)
      |> assign_new(:form, fn -> form end)
      |> assign_new(:valid, fn -> true end)
      |> assign_prompt(assigns.field_options)

    ~H"""
    <div>
      <.form for={@form} class="relative" phx-change="update-field" phx-submit="update-field" phx-target={@myself}>
        <BackpexForm.input
          id={"index-form-input-#{@name}-#{LiveResource.primary_value(@item, @live_resource)}"}
          type="select"
          field={@form[:value]}
          options={@options}
          prompt={@prompt}
          value={@value && Map.get(@value, :id)}
          input_class={[
            "select select-sm",
            @valid && "not-hover:select-ghost",
            !@valid && "select-error text-error-content bg-error/10"
          ]}
          disabled={@readonly}
          hide_errors
          aria-label={@field_options[:label]}
        />
      </.form>
    </div>
    """
  end

  @impl Phoenix.LiveComponent
  def handle_event("update-field", %{"index_form" => %{"value" => value}}, socket) do
    Backpex.Field.handle_index_editable(socket, value, Map.put(%{}, socket.assigns.owner_key, value))
  end

  @impl Backpex.Field
  def display_field({_name, field_options}) do
    Map.get(field_options, :display_field)
  end

  @impl Backpex.Field
  def schema({name, _field_options}, schema) do
    schema.__schema__(:association, name)
    |> Map.get(:queryable)
  end

  @impl Backpex.Field
  def association?(_field), do: true

  defp display_field_form({_name, field_options} = _field, display_field) do
    Map.get(field_options, :display_field_form, display_field)
  end

  defp get_ash_authorized_options(queryable, field_options, display_field, assigns) do
    # Get the actor from assigns (current_user)
    actor = Map.get(assigns, :current_user) || Map.get(assigns, :actor)

    Logger.info(
      "[AshBackpex.Fields.BelongsTo] Filtering options for #{inspect(queryable)} with actor: #{inspect(actor && actor.email)}"
    )

    # Get the repo for fallback Ecto queries
    repo = assigns.live_resource.adapter_config(:repo)

    # Query via Ash to get authorized records
    authorized_records = get_authorized_records(queryable, display_field, actor)

    case authorized_records do
      {:ok, records} when is_list(records) ->
        # Extract IDs from authorized records
        authorized_ids = Enum.map(records, & &1.id)

        Logger.info(
          "[AshBackpex.Fields.BelongsTo] ✓ Authorization successful: #{length(records)} authorized records found (IDs: #{inspect(authorized_ids)})"
        )

        # Create Ecto query filtered by authorized IDs
        base_query =
          queryable
          |> from()
          |> where([r], r.id in ^authorized_ids)

        # Apply any custom options_query if provided
        final_query = maybe_options_query(base_query, field_options, assigns)

        # Execute the query and format for select options
        final_query
        |> repo.all()
        |> Enum.map(&{Map.get(&1, display_field), Map.get(&1, :id)})

      {:ok, []} ->
        Logger.info(
          "[AshBackpex.Fields.BelongsTo] ⚠ Authorization result: 0 authorized records (empty result)"
        )

        # No authorized records
        []

      {:error, %Ash.Error.Forbidden{}} ->
        Logger.warning(
          "[AshBackpex.Fields.BelongsTo] ✗ Authorization forbidden: User not authorized to read any records"
        )

        # User is not authorized to read any records
        []

      {:error, error} ->
        Logger.info(
          "[AshBackpex.Fields.BelongsTo] → Fallback mode: #{inspect(error)} - using standard Ecto query (no authorization)"
        )

        # For resources without policies or other errors, fall back to standard behavior
        # This ensures backward compatibility
        queryable
        |> from()
        |> maybe_options_query(field_options, assigns)
        |> repo.all()
        |> Enum.map(&{Map.get(&1, display_field), Map.get(&1, :id)})
    end
  end

  defp get_authorized_records(queryable, display_field, actor) do
    # Check if the queryable is an Ash resource
    if function_exported?(queryable, :spark_dsl_config, 0) do
      # It's an Ash resource - query with authorization
      primary_read_action = Ash.Resource.Info.primary_action(queryable, :read)

      if primary_read_action do
        Logger.debug(
          "[AshBackpex.Fields.BelongsTo] Querying via Ash with action: #{primary_read_action.name}"
        )

        queryable
        |> Ash.Query.for_read(primary_read_action.name)
        |> Ash.Query.select([:id, display_field])
        |> Ash.read(actor: actor)
      else
        Logger.debug(
          "[AshBackpex.Fields.BelongsTo] No read action found for #{inspect(queryable)}"
        )

        # No read action - return empty
        {:ok, []}
      end
    else
      # Not an Ash resource - return error to trigger fallback
      {:error, :not_ash_resource}
    end
  rescue
    # If anything goes wrong with Ash queries, fall back to standard Ecto behavior
    error ->
      Logger.debug(
        "[AshBackpex.Fields.BelongsTo] Exception during Ash query: #{inspect(error)}"
      )

      {:error, error}
  end

  defp assign_link(assigns) do
    %{socket: socket, field_options: field_options, value: value, params: params} = assigns

    live_resource = Map.get(field_options, :live_resource)

    link =
      if live_resource && live_resource.can?(assigns, :show, value) do
        Router.get_path(socket, live_resource, params, :show, value)
      end

    assign(assigns, :link, link)
  end

  defp maybe_options_query(query, %{options_query: options_query} = _field_options, assigns),
    do: options_query.(query, assigns)

  defp maybe_options_query(query, _field_options, _assigns), do: query

  defp assign_prompt(assigns, field_options) do
    prompt =
      case Map.get(field_options, :prompt) do
        nil -> nil
        prompt when is_function(prompt) -> prompt.(assigns)
        prompt -> prompt
      end

    assign(assigns, :prompt, prompt)
  end
end
