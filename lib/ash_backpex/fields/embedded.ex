defmodule AshBackpex.Fields.Embedded do
  @moduledoc """
  Configuration contract for a singular typed embedded Ash resource.

  Configure the embedded resource's fields recursively with `child_fields` in
  `AshBackpex.LiveResource`. This module defines the configuration boundary used
  by AshBackpex's singular embedded-resource renderer. It is distinct from
  `Backpex.Fields.InlineCRUD`, which represents repeated children.

  The parent Ash action accepts a singular embedded value as a map. Repeated
  typed embeds use InlineCRUD and are normalized to ordered lists of maps.
  """

  @config_schema [
    child_fields: [
      doc: "Field definitions for the singular typed embedded Ash resource.",
      type: :keyword_list,
      required: true
    ]
  ]

  use Backpex.Field, config_schema: @config_schema

  @impl Phoenix.LiveComponent
  def update(%{field: {name, field_options}} = assigns, socket) do
    child_fields =
      field_options.child_fields
      |> validate_child_fields(name)
      |> Backpex.LiveResource.fields_by_action(assigns.live_action)

    socket =
      socket
      |> assign(assigns)
      |> assign_new(:hide_label, fn -> false end)
      |> assign_new(:readonly, fn -> false end)
      |> assign(:child_fields, child_fields)

    {:ok, assign_form_errors(socket, assigns.type)}
  end

  @impl Backpex.Field
  def render_value(assigns) do
    assigns = assign(assigns, :child_fields, child_fields_for_item(assigns.child_fields, assigns))

    ~H"""
    <div class="flex flex-col gap-2">
      <div :for={{child_name, _options} <- @child_fields}>
        {Backpex.HTML.Resource.inlined_resource_field(
          assign(assigns,
            id: "embedded_#{@id}_#{child_name}",
            fields: @child_fields,
            item: @value || %{},
            name: child_name
          )
        )}
      </div>
    </div>
    """
  end

  @impl Backpex.Field
  def render_form(assigns) do
    ~H"""
    <div>
      <Layout.field_container>
        <:label :if={not @hide_label} align={Backpex.Field.align_label(@field_options, assigns, :top)}>
          <Layout.input_label for={@form[@name]} text={@field_options[:label]} />
        </:label>

        <.inputs_for :let={embedded_form} field={@form[@name]} skip_persistent_id>
          <% child_fields = child_fields_for_form(@child_fields, embedded_form, assigns) %>
          <fieldset id={"embedded-fieldset-#{embedded_form.id}"} class="flex flex-col gap-3">
            <legend :if={@hide_label} class="sr-only">{@field_options[:label]}</legend>

            <div :for={{child_name, _options} <- child_fields}>
              {Backpex.HTML.Resource.resource_form_field(
                assign(assigns,
                  fields: child_fields,
                  form: embedded_form,
                  hide_label: false,
                  name: child_name
                )
              )}
            </div>
          </fieldset>
        </.inputs_for>

        <BackpexForm.error :for={msg <- @errors} class="mt-1">{msg}</BackpexForm.error>

        <%= if help_text = Backpex.Field.help_text(@field_options, assigns) do %>
          <Backpex.HTML.Form.help_text class="mt-1">{help_text}</Backpex.HTML.Form.help_text>
        <% end %>
      </Layout.field_container>
    </div>
    """
  end

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

  defp child_fields_for_form(child_fields, form, assigns) do
    nested_assigns =
      assigns
      |> assign(:form, form)
      |> assign(:item, form.data)

    child_fields = visible_child_fields(child_fields, nested_assigns)

    if assigns.readonly do
      Enum.map(child_fields, fn {name, options} -> {name, Map.put(options, :readonly, true)} end)
    else
      child_fields
    end
  end

  defp child_fields_for_item(child_fields, assigns),
    do: visible_child_fields(child_fields, assigns)

  defp visible_child_fields(child_fields, assigns) do
    child_fields
    |> Backpex.LiveResource.fields_by_can(assigns)
    |> Enum.filter(fn
      {_name, %{visible: visible}} -> visible.(assigns)
      _field -> true
    end)
  end
end
