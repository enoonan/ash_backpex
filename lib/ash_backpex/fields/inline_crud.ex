defmodule AshBackpex.Fields.InlineCRUD do
  @moduledoc """
  AshBackpex's form renderer for `Backpex.Fields.InlineCRUD`.

  It adds move-up and move-down controls and repeats child labels for every
  entry. Configure `Backpex.Fields.InlineCRUD` in the DSL; AshBackpex selects
  this renderer automatically. It supports `has_many` relationships and arrays
  of typed embedded Ash resources; nested arrays normalize independently.
  """

  use Backpex.Field, config_schema: Backpex.Fields.InlineCRUD.config_schema()

  require Backpex

  @impl Phoenix.LiveComponent
  def update(%{field: {name, field_options}} = assigns, socket) do
    child_fields =
      field_options.child_fields
      |> validate_child_fields(name)
      |> Backpex.LiveResource.fields_by_action(assigns.live_action)
      |> maybe_filter_child_fields(assigns)

    socket =
      socket
      |> assign(assigns)
      |> assign_new(:hide_label, fn -> false end)
      |> assign_new(:readonly, fn -> false end)
      |> assign(:child_fields, child_fields)

    {:ok, assign_form_errors(socket, assigns.type)}
  end

  @impl Backpex.Field
  defdelegate render_value(assigns), to: Backpex.Fields.InlineCRUD

  @impl Backpex.Field
  def render_form(assigns) do
    entry_label = assigns.field_options[:label]

    assigns =
      assign(assigns,
        last_index: repeated_count(assigns.form[assigns.name].value) - 1,
        entry_label: entry_label,
        add_label: add_label(entry_label, assigns.live_resource),
        delete_label: delete_label(entry_label, assigns.live_resource),
        actions_label: actions_label(entry_label, assigns.live_resource)
      )

    ~H"""
    <div>
      <Layout.field_container>
        <:label :if={not @hide_label} align={Backpex.Field.align_label(@field_options, assigns, :top)}>
          <Layout.input_label
            id={"inline-crud-label-#{control_id(@form, @name)}"}
            as="span"
            text={@field_options[:label]}
          />
        </:label>

        <div class="flex flex-col">
          <.inputs_for :let={f_nested} field={@form[@name]}>
            <% f_nested = stable_child_form(f_nested) %>
            <% child_fields = child_fields_for_form(@child_fields, f_nested, assigns) %>
            <input
              type="hidden"
              name={control_name(@form, @name, "order")}
              value={f_nested.index}
              tabindex="-1"
              aria-hidden="true"
            />

            <fieldset
              id={"inline-crud-entry-#{f_nested.id}"}
              class="inline-crud-entry inline-crud-entry--bounded mb-4 min-w-0 rounded-box border border-base-300 bg-base-200/20 p-4"
            >
              <legend class="sr-only">{@entry_label}</legend>
              <div class="grid grid-cols-[repeat(auto-fit,minmax(min(100%,16rem),1fr))] items-start gap-x-4 gap-y-3">
                <div
                  :for={{child_field_name, child_field_options} <- child_fields}
                  class={child_field_class(child_field_options, assign(assigns, :form, f_nested))}
                >
                  <div
                    id={"inline-crud-header-label-#{f_nested.id}-#{child_field_name}"}
                    class="mb-2 text-xs"
                  >
                    {child_field_options.label}
                  </div>
                  {Backpex.HTML.Resource.resource_form_field(
                    assign(assigns,
                      hide_label: true,
                      aria_labelledby:
                        "inline-crud-label-#{control_id(@form, @name)} inline-crud-header-label-#{f_nested.id}-#{child_field_name}",
                      fields: child_fields,
                      name: child_field_name,
                      form: f_nested
                    )
                  )}
                </div>
              </div>

              <div
                :if={not @readonly}
                class="inline-crud-entry-actions mt-3 flex flex-wrap items-center justify-between border-base-300 border-t pt-3"
                style="gap: 0.375rem"
                aria-label={@actions_label}
              >
                <.add_control
                  :if={f_nested.index == @last_index}
                  control_id={control_id(@form, @name)}
                  control_name={control_name(@form, @name, "order")}
                  label={@add_label}
                />

                <div class="ml-auto flex flex-wrap items-center" style="gap: 0.375rem">
                  <.move_control
                    control_id={control_id(@form, @name)}
                    control_name={control_name(@form, @name, "move_up")}
                    index={f_nested.index}
                    last_index={@last_index}
                    direction="up"
                    entry_label={@entry_label}
                    live_resource={@live_resource}
                  />
                  <.move_control
                    control_id={control_id(@form, @name)}
                    control_name={control_name(@form, @name, "move_down")}
                    index={f_nested.index}
                    last_index={@last_index}
                    direction="down"
                    entry_label={@entry_label}
                    live_resource={@live_resource}
                  />

                  <label for={"#{control_id(@form, @name)}-delete-#{f_nested.index}"}>
                    <input
                      id={"#{control_id(@form, @name)}-delete-#{f_nested.index}"}
                      type="checkbox"
                      name={control_name(@form, @name, "delete")}
                      value={f_nested.index}
                      aria-label={@delete_label}
                      class="hidden"
                    />
                    <div class="btn btn-outline btn-sm btn-error">
                      <span>{@delete_label}</span>
                      <Backpex.HTML.CoreComponents.icon name="hero-trash" class="size-5" />
                    </div>
                  </label>
                </div>
              </div>
            </fieldset>
          </.inputs_for>

          <input
            type="hidden"
            name={control_name(@form, @name, "delete")}
            tabindex="-1"
            aria-hidden="true"
          />
        </div>
        <.add_control
          :if={@last_index < 0 and not @readonly}
          control_id={control_id(@form, @name)}
          control_name={control_name(@form, @name, "order")}
          label={@add_label}
        />

        <BackpexForm.error :for={msg <- @errors} class="mt-1">{msg}</BackpexForm.error>

        <%= if help_text = Backpex.Field.help_text(@field_options, assigns) do %>
          <Backpex.HTML.Form.help_text class="mt-1">{help_text}</Backpex.HTML.Form.help_text>
        <% end %>
      </Layout.field_container>
    </div>
    """
  end

  attr(:control_id, :string, required: true)
  attr(:control_name, :string, required: true)
  attr(:index, :integer, required: true)
  attr(:last_index, :integer, required: true)
  attr(:direction, :string, values: ~w(up down), required: true)
  attr(:entry_label, :string, required: true)
  attr(:live_resource, :atom, required: true)

  defp move_control(assigns) do
    assigns =
      assign(assigns,
        label: move_label(assigns.direction, assigns.entry_label, assigns.live_resource),
        disabled:
          (assigns.direction == "up" and assigns.index == 0) or
            (assigns.direction == "down" and assigns.index == assigns.last_index)
      )

    ~H"""
    <label for={"#{@control_id}-move-#{@direction}-#{@index}"}>
      <input
        id={"#{@control_id}-move-#{@direction}-#{@index}"}
        type="checkbox"
        name={@control_name}
        value={@index}
        aria-label={@label}
        disabled={@disabled}
        class="hidden"
      />

      <div class={["btn btn-outline btn-sm", @disabled && "btn-disabled"]}>
        <span>{@label}</span>
        <Backpex.HTML.CoreComponents.icon
          :if={@direction == "up"}
          name="hero-arrow-up-solid"
          class="size-5"
        />
        <Backpex.HTML.CoreComponents.icon
          :if={@direction == "down"}
          name="hero-arrow-down-solid"
          class="size-5"
        />
      </div>
    </label>
    """
  end

  attr(:control_id, :string, required: true)
  attr(:control_name, :string, required: true)
  attr(:label, :string, required: true)

  defp add_control(assigns) do
    ~H"""
    <label for={"#{@control_id}-add"}>
      <input
        id={"#{@control_id}-add"}
        name={@control_name}
        type="checkbox"
        aria-label={@label}
        class="hidden"
      />
      <span class="btn btn-outline btn-sm btn-primary">{@label}</span>
    </label>
    """
  end

  defp add_label(entry_label, live_resource),
    do: Backpex.__({"Add %{entry}", %{entry: entry_label}}, live_resource)

  defp delete_label(entry_label, live_resource),
    do: Backpex.__({"Delete %{entry}", %{entry: entry_label}}, live_resource)

  defp actions_label(entry_label, live_resource),
    do: Backpex.__({"%{entry} actions", %{entry: entry_label}}, live_resource)

  defp move_label("up", entry_label, live_resource),
    do: Backpex.__({"Move %{entry} up", %{entry: entry_label}}, live_resource)

  defp move_label("down", entry_label, live_resource),
    do: Backpex.__({"Move %{entry} down", %{entry: entry_label}}, live_resource)

  defp stable_child_form(%{params: %{"_persistent_id" => persistent_id}} = form) do
    persistent_suffix = "_#{persistent_id}"
    indexed_suffix = "#{persistent_suffix}_#{form.index}"

    stable_id =
      cond do
        String.ends_with?(form.id, indexed_suffix) ->
          String.replace_suffix(form.id, "_#{form.index}", "")

        String.ends_with?(form.id, persistent_suffix) ->
          form.id

        true ->
          "#{form.id}#{persistent_suffix}"
      end

    %{form | id: stable_id}
  end

  defp stable_child_form(form), do: form

  defp validate_child_fields(fields, parent_name) do
    Enum.map(fields, fn {name, options} = field ->
      options.module.validate_config!(field, parent_name)
      |> Map.new()
      |> then(&{name, &1})
    end)
  end

  defp assign_form_errors(socket, :form) do
    %{form: form, name: name, field_options: field_options} = socket.assigns
    errors = if Phoenix.Component.used_input?(form[name]), do: form[name].errors, else: []
    translate_error_fun = Map.get(field_options, :translate_error, &Function.identity/1)

    assign(socket, :errors, BackpexForm.translate_form_errors(errors, translate_error_fun))
  end

  defp assign_form_errors(socket, _type), do: socket

  defp maybe_filter_child_fields(child_fields, %{type: :form}), do: child_fields

  defp maybe_filter_child_fields(child_fields, assigns) do
    child_fields
    |> Backpex.LiveResource.fields_by_can(assigns)
    |> Enum.filter(fn
      {_name, %{visible: visible}} -> visible.(assigns)
      _field -> true
    end)
  end

  defp child_fields_for_form(child_fields, form, assigns) do
    nested_assigns =
      assigns
      |> assign(:form, form)
      |> assign(:item, form.data)

    child_fields =
      child_fields
      |> Backpex.LiveResource.fields_by_can(nested_assigns)
      |> Enum.filter(fn
        {_name, %{visible: visible}} -> visible.(nested_assigns)
        _field -> true
      end)

    if assigns.readonly do
      Enum.map(child_fields, fn {name, options} -> {name, Map.put(options, :readonly, true)} end)
    else
      child_fields
    end
  end

  defp control_name(form, name, action), do: "#{form.name}[#{name}_#{action}][]"
  defp control_id(form, name), do: "#{form.id}_#{name}"

  defp repeated_count(value) when is_list(value), do: length(value)
  defp repeated_count(value) when is_map(value) and not is_struct(value), do: map_size(value)
  defp repeated_count(_value), do: 0

  @impl Backpex.Field
  defdelegate association?(field), to: Backpex.Fields.InlineCRUD

  @impl Backpex.Field
  defdelegate schema(field, schema), to: Backpex.Fields.InlineCRUD

  defp child_field_class(%{class: class} = child_field_options, assigns) when is_function(class),
    do: [child_field_layout_class(child_field_options), class.(assigns)]

  defp child_field_class(%{class: class} = child_field_options, _assigns) when is_binary(class),
    do: [child_field_layout_class(child_field_options), class]

  defp child_field_class(child_field_options, _assigns),
    do: child_field_layout_class(child_field_options)

  defp child_field_layout_class(%{module: module})
       when module in [
              AshBackpex.Fields.InlineCRUD,
              Backpex.Fields.InlineCRUD,
              AshBackpex.Fields.Embedded
            ],
       do: "col-span-full"

  defp child_field_layout_class(_child_field_options), do: "min-w-0"
end
