defmodule AshBackpex.Fields.InlineCRUD do
  @moduledoc """
  AshBackpex's form renderer for `Backpex.Fields.InlineCRUD`.

  It adds move-up and move-down controls and repeats child labels for every
  entry. Configure `Backpex.Fields.InlineCRUD` in the DSL; AshBackpex selects
  this renderer automatically.
  """

  use Backpex.Field, config_schema: Backpex.Fields.InlineCRUD.config_schema()

  require Backpex

  @impl Phoenix.LiveComponent
  defdelegate update(assigns, socket), to: Backpex.Fields.InlineCRUD

  @impl Backpex.Field
  defdelegate render_value(assigns), to: Backpex.Fields.InlineCRUD

  @impl Backpex.Field
  def render_form(assigns) do
    assigns =
      assign(assigns, :last_index, length(List.wrap(assigns.form[assigns.name].value)) - 1)

    ~H"""
    <div>
      <Layout.field_container>
        <:label align={Backpex.Field.align_label(@field_options, assigns, :top)}>
          <Layout.input_label id={"inline-crud-label-#{@name}"} as="span" text={@field_options[:label]} />
        </:label>

        <div class="flex flex-col">
          <.inputs_for :let={f_nested} field={@form[@name]}>
            <input type="hidden" name={"change[#{@name}_order][]"} value={f_nested.index} tabindex="-1" aria-hidden="true" />

            <div
              id={"inline-crud-entry-#{@name}-#{f_nested.params["_persistent_id"] || f_nested.index}"}
              class="mb-3"
            >
              <div class="flex items-start gap-x-4">
                <div
                  :for={{child_field_name, child_field_options} <- @child_fields}
                  class={child_field_class(child_field_options, assigns)}
                >
                  <div
                    id={"inline-crud-header-label-#{@name}-#{child_field_name}-#{f_nested.index}"}
                    class="mb-2 text-xs"
                  >
                    {child_field_options.label}
                  </div>
                  {Backpex.HTML.Resource.resource_form_field(
                    assign(assigns,
                      hide_label: true,
                      aria_labelledby:
                        "inline-crud-label-#{@name} inline-crud-header-label-#{@name}-#{child_field_name}-#{f_nested.index}",
                      fields: @child_fields,
                      name: child_field_name,
                      form: f_nested
                    )
                  )}
                </div>
              </div>

              <div class="flex items-center" style="margin-top: 0.75rem">
                <input
                  :if={f_nested.index == @last_index}
                  name={"change[#{@name}_order][]"}
                  type="checkbox"
                  aria-label={Backpex.__("Add entry", @live_resource)}
                  class="btn btn-outline btn-sm btn-primary"
                />

                <div class="flex items-center" style="margin-left: auto; gap: 0.75rem">
                  <.move_control
                    name={@name}
                    index={f_nested.index}
                    last_index={@last_index}
                    direction="up"
                    live_resource={@live_resource}
                  />
                  <.move_control
                    name={@name}
                    index={f_nested.index}
                    last_index={@last_index}
                    direction="down"
                    live_resource={@live_resource}
                  />

                  <label for={"#{@name}-checkbox-delete-#{f_nested.index}"}>
                    <input
                      id={"#{@name}-checkbox-delete-#{f_nested.index}"}
                      type="checkbox"
                      name={"change[#{@name}_delete][]"}
                      value={f_nested.index}
                      class="hidden"
                    />
                    <div class="btn btn-outline btn-sm btn-error">
                      <span class="sr-only">{Backpex.__("Delete", @live_resource)}</span>
                      <Backpex.HTML.CoreComponents.icon name="hero-trash" class="size-5" />
                    </div>
                  </label>
                </div>
              </div>
            </div>
          </.inputs_for>

          <input type="hidden" name={"change[#{@name}_delete][]"} tabindex="-1" aria-hidden="true" />
        </div>
        <input
          :if={@last_index < 0}
          name={"change[#{@name}_order][]"}
          type="checkbox"
          aria-label={Backpex.__("Add entry", @live_resource)}
          class="btn btn-outline btn-sm btn-primary"
        />

        <BackpexForm.error :for={msg <- @errors} class="mt-1">{msg}</BackpexForm.error>

        <%= if help_text = Backpex.Field.help_text(@field_options, assigns) do %>
          <Backpex.HTML.Form.help_text class="mt-1">{help_text}</Backpex.HTML.Form.help_text>
        <% end %>
      </Layout.field_container>
    </div>
    """
  end

  attr(:name, :atom, required: true)
  attr(:index, :integer, required: true)
  attr(:last_index, :integer, required: true)
  attr(:direction, :string, values: ~w(up down), required: true)
  attr(:live_resource, :atom, required: true)

  defp move_control(assigns) do
    assigns =
      assign(assigns,
        label: move_label(assigns.direction, assigns.live_resource),
        disabled:
          (assigns.direction == "up" and assigns.index == 0) or
            (assigns.direction == "down" and assigns.index == assigns.last_index)
      )

    ~H"""
    <label for={"#{@name}-checkbox-move-#{@direction}-#{@index}"}>
      <input
        id={"#{@name}-checkbox-move-#{@direction}-#{@index}"}
        type="checkbox"
        name={"change[#{@name}_move_#{@direction}][]"}
        value={@index}
        aria-label={@label}
        disabled={@disabled}
        class="hidden"
      />

      <div class={["btn btn-outline btn-sm", @disabled && "btn-disabled"]}>
        <span class="sr-only">{@label}</span>
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

  defp move_label("up", live_resource), do: Backpex.__("Move up", live_resource)
  defp move_label("down", live_resource), do: Backpex.__("Move down", live_resource)

  @impl Backpex.Field
  defdelegate association?(field), to: Backpex.Fields.InlineCRUD

  @impl Backpex.Field
  defdelegate schema(field, schema), to: Backpex.Fields.InlineCRUD

  defp child_field_class(%{class: class}, assigns) when is_function(class), do: class.(assigns)
  defp child_field_class(%{class: class}, _assigns) when is_binary(class), do: class
  defp child_field_class(_child_field_options, _assigns), do: "flex-1"
end
