defmodule AshBackpex.LiveResource.Dsl do
  @moduledoc """
  defmodule MyAppWeb.Live.PostLive do
    use AshBackpex.Live

    backpex do
      resource MyApp.Blog.Post
      load [:author, :comments]
      fields do
        field :title, Backpex.Fields.Text
        field :author, Backpex.Fields.BelongsTo
        field :comments, Backpex.Fields.HasMany, only: [:show]
      end
      singular_name "Post"
      plural_name "Posts"
    end
  end
  """

  defmodule Field do
    defstruct [
      :attribute,
      :default,
      :render,
      :render_form,
      :custom_alias,
      :align,
      :align_label,
      :searchable,
      :orderable,
      :visible,
      :can?,
      :panel,
      :index_editable,
      :index_column_class,
      :only,
      :except,
      :translate_error,
      :module,
      :label,
      :help_text,
      :debounce,
      :throttle,
      :placeholder,
      :options,
      :display_field,
      :live_resource
    ]
  end

  @field %Spark.Dsl.Entity{
    name: :field,
    args: [:attribute],
    target: AshBackpex.LiveResource.Dsl.Field,
    describe:
      "Configures an Ash Resource attribute, relation, calculation or aggregate as a field to display in Backpex.",
    schema:
      Keyword.new([
        {:attribute,
         [
           type: :atom,
           required: true,
           doc:
             "The attribute, relation, calculation, or aggregate on the Ash Resource that this field corresponds to."
         ]}
      ])
      |> Keyword.merge(Backpex.Field.default_config_schema())
      |> Keyword.merge(
        module: [
          type: :module,
          required: false,
          doc:
            "The Backpex module that should be used to display and load the field. Will attempt to provide a sensible default based on the attribute's configured field type."
        ],
        label: [
          type: :string,
          required: false,
          doc:
            "The label that should appear on the field in the admin. Will default to a capitalized version of the attribute atom, e.g., \"inserted_at\" will become \"Inserted At\""
        ],
        help_text: [
          type: {:or, [:string, {:literal, :description}]},
          required: false,
          doc:
            "Optional text to be displayed below the input on form views. Pass `:description` to use the attribute's configured description."
        ],
        debounce: [
          doc: "Timeout value (in milliseconds), \"blur\" or function that receives the assigns.",
          type: {:or, [:pos_integer, :string, {:fun, 1}]}
        ],
        throttle: [
          doc: "Timeout value (in milliseconds) or function that receives the assigns.",
          type: {:or, [:pos_integer, {:fun, 1}]}
        ],
        readonly: [
          doc:
            "Sets the field to readonly. Also see the [panels](/guides/fields/readonly.md) guide.",
          type: {:or, [:boolean, {:fun, 1}]}
        ],
        panel: [
          doc:
            "The panel key this field belongs to. Must match a key defined in the panels configuration.",
          type: :atom
        ],
        # TEXT FIELDS
        placeholder: [
          doc: "Placeholder value or function that receives the assigns.",
          type: {:or, [:string, {:fun, 1}]}
        ],
        # RELATIONSHIP FIELDS
        display_field: [
          doc:
            "The field of the relation to be used for searching, ordering and displaying values.",
          type: :atom
          # required: true
        ],
        display_field_form: [
          doc: "Field to be used to display form values.",
          type: :atom
        ],
        live_resource: [
          doc:
            "The live resource of the association. Used to generate links navigating to the association.",
          type: :module
        ],
        link_assocs: [
          doc:
            "Whether to automatically generate links to the association items. The default value is true.",
          type: :boolean,
          required: false
        ],
        options_query: [
          doc: """
          Manipulates the list of available options in the select.

          Defaults to `fn (query, _field) -> query end` which returns all entries.
          """,
          type: {:fun, 2}
        ],
        prompt: [
          doc:
            "The text to be displayed when no option is selected or function that receives the assigns.",
          type: {:or, [:string, {:fun, 1}]}
        ],
        # TIME FIELDS (e.g. Date, Time, DateTime)
        format: [
          doc: """
          Format string which will be used to format the date time value or function that formats the date time.

          Can also be a function wich receives a `DateTime` and must return a string.
          """,
          type: {:or, [:string, {:fun, 1}]},
          default: "%Y-%m-%d"
        ],
        # SELECTABLE FIELDS
        options: [
          doc: "List of options or function that receives the assigns.",
          type: {:or, [{:list, :any}, {:fun, 1}]}
          # required: true
        ],
        # TEXTAREA
        rows: [
          doc: "Number of visible text lines for the control.",
          type: :non_neg_integer,
          default: 2
        ]
      )
      |> Keyword.drop([:select])
  }

  @fields %Spark.Dsl.Section{
    name: :fields,
    entities: [@field]
  }

  defmodule Filter do
    defstruct [:attribute, :module, :label]
  end

  @filter %Spark.Dsl.Entity{
    name: :filter,
    args: [:attribute],
    target: AshBackpex.LiveResource.Dsl.Filter,
    describe: "Configures a filter for the resource",
    schema: [
      {:attribute, [type: :atom, required: true, doc: "The attribute to filter on"]},
      {:module,
       [
         type: :module,
         required: true,
         doc: "The module to use for the filter. You must create the module"
       ]},
      {:label,
       [
         type: :string,
         doc: "The label for the filter. Defaults to the attribute name, title_cased"
       ]}
    ]
  }

  @filters %Spark.Dsl.Section{
    name: :filters,
    entities: [@filter]
  }

  defmodule ItemAction do
    defstruct [:name, :module]
  end

  @item_action %Spark.Dsl.Entity{
    name: :action,
    args: [:name, :module],
    target: AshBackpex.LiveResource.Dsl.ItemAction,
    describe: "Configures an item action for the resource",
    schema: [
      {:name, [type: :atom, required: true, doc: "The name of the item action"]},
      {:module,
       [
         type: :module,
         required: true,
         doc: "The module to use for the item action. You must create the module"
       ]}
    ]
  }

  @item_actions %Spark.Dsl.Section{
    name: :item_actions,
    schema: [
      strip_default: [
        type: {:list, :atom},
        doc: "Default Backpex actions to remove from the live resource"
      ]
    ],
    entities: [@item_action]
  }

  @backpex %Spark.Dsl.Section{
    name: :backpex,
    schema: [
      resource: [
        type: :atom,
        required: true,
        doc: "The Ash resource that the Backpex Live resource should be connect to."
      ],
      layout: [
        type: {:tuple, [:module, :atom]},
        required: true,
        doc: "The liveview layout, e.g.: {MyAppWeb.Layouts, :admin}"
      ],
      load: [
        type: {:list, :any},
        default: []
      ],
      create_action: [
        type: :atom,
        doc:
          "The create action to be used when creating resources. Will default to the primary create action."
      ],
      read_action: [
        type: :atom,
        doc:
          "The read action to be used when reading resources. Will default to the primary read action."
      ],
      update_action: [
        type: :atom,
        doc:
          "The update action to be used when updating resources. Will default to the primary update action."
      ],
      destroy_action: [
        type: :atom,
        doc:
          "The destroy action to be used when destroying resources. Will default to the primary destroy action."
      ],
      update_changeset: [
        doc: """
        Changeset to use when updating items. Additional metadata is passed as a keyword list via the third parameter:
        - `:assigns` - the assigns
        - `:target` - the name of the `form` target that triggered the changeset call. Default to `nil` if the call was not triggered by a form field.
        """,
        type: {:fun, 3}
      ],
      create_changeset: [
        doc: """
        Changeset to use when creating items. Additional metadata is passed as a keyword list via the third parameter:
        - `:assigns` - the assigns
        - `:target` - the name of the `form` target that triggered the changeset call. Default to `nil` if the call was not triggered by a form field.
        """,
        type: {:fun, 3}
      ],
      singular_name: [
        type: :string,
        doc: "The singular name for the resource that will appear in the admin. E.g., \"Post\""
      ],
      plural_name: [
        type: :string,
        doc: "The plural name for the resource taht will appear i nthe admin. E.g., \"Posts\""
      ],
      panels: [
        type: :keyword_list,
        doc:
          "Panels to be displayed in the admin create/edit forms. Format: [panel_key: \"Panel Title\"]"
      ]
    ],
    sections: [@fields, @filters, @item_actions]
  }

  use Spark.Dsl.Extension,
    sections: [@backpex],
    transformers: [AshBackpex.LiveResource.Transformers.GenerateBackpex]
end
