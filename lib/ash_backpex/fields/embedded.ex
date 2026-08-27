defmodule AshBackpex.Fields.Embedded do
  @moduledoc """
  Configuration contract for a singular typed embedded Ash resource.

  Configure the embedded resource's fields recursively with `child_fields` in
  `AshBackpex.LiveResource`. This module defines the configuration boundary used
  by AshBackpex's singular embedded-resource renderer. It is distinct from
  `Backpex.Fields.InlineCRUD`, which represents repeated children.
  """

  @config_schema [
    child_fields: [
      doc: "Field definitions for the singular typed embedded Ash resource.",
      type: :keyword_list,
      required: true
    ]
  ]

  use Backpex.Field, config_schema: @config_schema

  @impl Backpex.Field
  def render_value(_assigns) do
    raise "AshBackpex.Fields.Embedded rendering is not available yet"
  end

  @impl Backpex.Field
  def render_form(_assigns) do
    raise "AshBackpex.Fields.Embedded rendering is not available yet"
  end
end
