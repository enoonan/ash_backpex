defmodule AshBackpex.LiveResource.Dsl do
  @moduledoc """
  DSL extension for defining AshBackpex LiveResources.

  This module defines the `backpex` DSL section and all its nested sections
  (`fields`, `filters`, `item_actions`) that configure how your Ash resource
  is presented in the Backpex admin interface.

  ## Sections

  - `backpex` - The root section containing all configuration
    - `fields` - Define which attributes, relationships, calculations, and aggregates to display
    - `filters` - Add filterable columns to the index view
    - `item_actions` - Add or remove actions available on individual items

  ## backpex Section Options

  ### Required Options

  - `resource` - The Ash resource module to connect to
  - `layout` - The LiveView layout function or tuple, e.g., `{MyAppWeb.Layouts, :admin}`

  ### Optional Options

  - `load` - List of relationships/calculations/aggregates to preload
  - `create_action` - Ash action for creating (defaults to primary create action)
  - `read_action` - Ash action for reading (defaults to primary read action)
  - `update_action` - Ash action for updating (defaults to primary update action)
  - `destroy_action` - Ash action for destroying (defaults to primary destroy action)
  - `create_changeset` - Custom changeset function for creates (3-arity)
  - `update_changeset` - Custom changeset function for updates (3-arity)
  - `singular_name` - Display name for single items (e.g., "Post")
  - `plural_name` - Display name for multiple items (e.g., "Posts")
  - `panels` - Keyword list of panel definitions for form organization
  - `pubsub` - PubSub configuration with `:server` and `:topic` keys
  - `per_page_options` - List of page size options (default: `[15, 50, 100]`)
  - `per_page_default` - Default page size (default: `15`)
  - `init_order` - Initial sort order, e.g., `%{by: :inserted_at, direction: :desc}`
  - `fluid?` - Whether layout fills entire width (default: `false`)
  - `full_text_search` - Column name for full-text search
  - `save_and_continue_button?` - Show "Save & Continue" button (default: `false`)
  - `on_mount` - LiveView on_mount hooks to attach

  ## fields Section

  The `fields` section defines which Ash resource fields appear in the admin interface.
  Fields can be attributes, relationships, calculations, or aggregates.

  ```elixir
  fields do
    field :title do
      searchable true
      label "Post Title"
    end

    field :content do
      module Backpex.Fields.Textarea
      rows 10
    end

    field :status do
      # Automatically uses Select for atom with one_of constraint
    end

    field :author do
      display_field :name
      live_resource MyAppWeb.Admin.UserLive
    end

    field :published_at do
      format "%Y-%m-%d %H:%M"
      only [:show, :index]  # Hide from forms
    end
  end
  ```

  ### Field Options

  #### Common Options (all field types)

  - `module` - Override the auto-derived Backpex.Fields.* module
  - `label` - Custom label (defaults to title-cased attribute name)
  - `only` - List of views where field appears (`:index`, `:show`, `:new`, `:edit`)
  - `except` - List of views where field is hidden
  - `searchable` - Enable text search on this field (default: `false`)
  - `orderable` - Allow sorting by this field
  - `visible` - Function to control visibility `fn assigns -> boolean end`
  - `can?` - Function to control access `fn assigns -> boolean end`
  - `panel` - Panel key this field belongs to (must match `panels` config)
  - `index_editable` - Allow inline editing on index view
  - `index_column_class` - CSS class for index column
  - `readonly` - Make field read-only (boolean or function)
  - `help_text` - Help text below input (string or `:description` to use attribute description)
  - `default` - Default value for new records
  - `render` - Custom render function
  - `render_form` - Custom form render function

  #### Text Field Options

  - `placeholder` - Placeholder text (string or function)
  - `debounce` - Debounce timeout in ms, "blur", or function
  - `throttle` - Throttle timeout in ms or function

  #### Textarea Options

  - `rows` - Number of visible text lines (default: `2`)

  #### Relationship Field Options (BelongsTo, HasMany)

  - `display_field` - Field to display from related record (e.g., `:name`)
  - `display_field_form` - Field to display in form select
  - `live_resource` - LiveResource module for the association (enables linking)
  - `link_assocs` - Auto-generate links to associations (default: `true` for HasMany)
  - `options_query` - Function to filter available options `fn query, field -> query end`
  - `prompt` - Text when no option selected (string or function)

  #### Date/Time Field Options

  - `format` - strftime format string or function (default: `"%Y-%m-%d"`)

  #### Select/MultiSelect Field Options

  - `options` - List of options or function returning options

  ## filters Section

  Add filters to the index view. Filter modules are auto-derived from Ash attribute types,
  so you only need to declare which attributes to filter on.

  ### Auto-Derivation Mapping

  | Ash Type | Filter Module | Notes |
  |----------|---------------|-------|
  | `Ash.Type.Boolean` | `AshBackpex.Filters.Boolean` | Checkboxes for true/false |
  | `Ash.Type.Atom` with `one_of` | `AshBackpex.Filters.Select` | Dropdown from constraint values |
  | `Ash.Type.String` with `one_of` | `AshBackpex.Filters.Select` | Dropdown from constraint values |
  | `Ash.Type.Integer` | `AshBackpex.Filters.Range` | Min/max number inputs |
  | `Ash.Type.Float` | `AshBackpex.Filters.Range` | Min/max number inputs |
  | `Ash.Type.Decimal` | `AshBackpex.Filters.Range` | Min/max number inputs |
  | `Ash.Type.Date` | `AshBackpex.Filters.Range` | Date range picker |
  | `Ash.Type.DateTime` | `AshBackpex.Filters.Range` | Datetime range picker |
  | `Ash.Type.UtcDatetime` | `AshBackpex.Filters.Range` | Datetime range picker |
  | `Ash.Type.NaiveDateTime` | `AshBackpex.Filters.Range` | Datetime range picker |
  | `{:array, Ash.Type.Atom}` with `one_of` | `AshBackpex.Filters.MultiSelect` | Checkboxes for multi-value |
  | `{:array, Ash.Type.String}` with `one_of` | `AshBackpex.Filters.MultiSelect` | Checkboxes for multi-value |

  ### Usage Examples

  ```elixir
  filters do
    # Boolean filter - renders true/false checkboxes
    filter :published

    # Select filter - auto-derived for atom/string with one_of constraint
    filter :status do
      label "Post Status"
    end

    # Range filter - auto-derived for numeric types
    filter :view_count

    # Range filter - auto-derived for date/datetime types
    filter :inserted_at

    # MultiSelect filter - auto-derived for array types with one_of constraint
    filter :tags

    # Explicit module override for custom filters
    filter :custom_field do
      module MyApp.Filters.CustomFilter
    end
  end
  ```

  ### Filter Types

  #### Boolean Filter

  Renders checkboxes for filtering true/false values. When both are selected,
  no filter is applied.

  #### Select Filter

  Renders a dropdown for single-value filtering. Options are auto-derived from
  `one_of` constraints, or can be provided via the `options` option.

  #### Range Filter

  Renders min/max input fields for range filtering. The input type (number, date,
  or datetime) is auto-derived from the Ash attribute type.

  #### MultiSelect Filter

  Renders checkboxes for multi-value filtering using `IN` queries. Useful for
  filtering records where a field matches any of the selected values.

  ### Filter Options

  - `module` - The filter module (optional, auto-derived from Ash attribute type if not specified)
  - `label` - Custom label (defaults to title-cased attribute name)
  - `options` - List of options for Select/MultiSelect filters (optional, auto-derived from `one_of` constraints)
  - `prompt` - Prompt text for empty selection (optional, string)
  - `type` - Type hint for Range filter: `:number`, `:date`, `:datetime` (optional, auto-derived)

  ## item_actions Section

  Configure per-item actions:

  ```elixir
  item_actions do
    # Remove default actions
    strip_default [:delete]

    # Add custom actions
    action :publish, MyApp.ItemActions.Publish
    action :archive, MyApp.ItemActions.Archive
  end
  ```

  ### Item Action Options

  - `strip_default` - List of default actions to remove (`:edit`, `:delete`, `:show`)
  - `action` - Add a custom item action with `action :name, ModuleName`

  ## Complete Example

  ```elixir
  defmodule MyAppWeb.Admin.PostLive do
    use AshBackpex.LiveResource

    backpex do
      resource MyApp.Blog.Post
      layout {MyAppWeb.Layouts, :admin}
      load [:author, :comments]

      singular_name "Blog Post"
      plural_name "Blog Posts"

      init_order %{by: :inserted_at, direction: :desc}
      per_page_default 25
      per_page_options [10, 25, 50, 100]

      panels [
        content: "Content",
        metadata: "Metadata"
      ]

      fields do
        field :title do
          searchable true
          panel :content
        end

        field :content do
          module Backpex.Fields.Textarea
          rows 15
          panel :content
        end

        field :status do
          panel :metadata
        end

        field :published_at do
          format "%B %d, %Y at %H:%M"
          panel :metadata
        end

        field :author do
          display_field :name
          live_resource MyAppWeb.Admin.UserLive
          panel :metadata
        end

        field :view_count do
          only [:show, :index]
        end
      end

      filters do
        # Select filter - auto-derived from atom with one_of constraint
        filter :status

        # Range filter - auto-derived from datetime attribute
        filter :published_at

        # Boolean filter - auto-derived from boolean attribute
        filter :featured

        # Range filter - auto-derived from integer attribute
        filter :view_count

        # MultiSelect filter - auto-derived from {:array, :atom} with one_of
        filter :tags
      end

      item_actions do
        strip_default [:delete]
        action :publish, MyApp.ItemActions.Publish
        action :archive, MyApp.ItemActions.Archive
      end
    end
  end
  ```
  """

  defmodule Field do
    @moduledoc """
    Internal struct representing a field configuration in the AshBackpex DSL.

    This struct holds all the configuration options for a single field in the
    `fields` section of a `backpex` block. Most users don't interact with this
    struct directly - it's populated by the DSL at compile time.

    See `AshBackpex.LiveResource.Dsl` for field configuration options.
    """
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
    @moduledoc """
    Internal struct representing a filter configuration in the AshBackpex DSL.

    This struct holds the configuration for a single filter in the `filters`
    section of a `backpex` block.

    ## Fields

    - `:attribute` - The Ash attribute to filter on (required)
    - `:module` - Filter module implementing the filter behavior (optional, auto-derived)
    - `:label` - Display label for the filter (optional, defaults to title-cased attribute)
    - `:options` - Options for Select/MultiSelect filters (optional, list or 1-arity function)
    - `:prompt` - Prompt text for empty selection (optional, string)
    - `:type` - Type hint for Range filter: `:number`, `:date`, `:datetime` (optional, auto-derived)

    See `AshBackpex.LiveResource.Dsl` for filter configuration options.
    """
    defstruct [:attribute, :module, :label, :options, :prompt, :type]
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
         required: false,
         doc:
           "The filter module to use. If not provided, will be auto-derived from the Ash attribute type (e.g., Boolean → AshBackpex.Filters.Boolean, atom with one_of → AshBackpex.Filters.Select)."
       ]},
      {:label,
       [
         type: :string,
         doc: "The label for the filter. Defaults to the attribute name, title_cased"
       ]},
      {:options,
       [
         type: {:or, [{:list, :any}, {:fun, 1}]},
         doc:
           "Options for Select/MultiSelect filters. List of options or 1-arity function receiving assigns."
       ]},
      {:prompt,
       [
         type: :string,
         doc: "Prompt text displayed when no option is selected. Defaults to \"Select...\""
       ]},
      {:type,
       [
         type: {:in, [:number, :date, :datetime]},
         doc:
           "Type hint for Range filter: :number, :date, or :datetime. Auto-derived from attribute type if not specified."
       ]}
    ]
  }

  @filters %Spark.Dsl.Section{
    name: :filters,
    entities: [@filter]
  }

  defmodule ItemAction do
    @moduledoc """
    Internal struct representing an item action configuration in the AshBackpex DSL.

    This struct holds the configuration for a single custom item action in the
    `item_actions` section of a `backpex` block.

    See `AshBackpex.LiveResource.Dsl` for item action configuration options.
    """
    defstruct [:name, :module, :only, :except]
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
       ]},
      only: [
        type: {:list, :atom},
        doc:
          "The only key is used to include specified placements, meaning the item action will only appear in the specified locations."
      ],
      except: [
        type: {:list, :atom},
        doc:
          "The except key is used to exclude specified placements, meaning the item action will appear in all locations except those specified."
      ]
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
        type: {:or, [{:fun, 1}, {:tuple, [:module, :atom]}]},
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
      ],
      pubsub: [
        doc: "PubSub configuration.",
        type: :keyword_list,
        required: false,
        keys: [
          server: [
            doc: "PubSub server of the project.",
            required: false,
            type: :atom
          ],
          topic: [
            doc: """
            The topic for PubSub.

            By default a stringified version of the live resource module name is used.
            """,
            required: false,
            type: :string
          ]
        ]
      ],
      per_page_options: [
        doc: "The page size numbers you can choose from.",
        type: {:list, :integer},
        default: [15, 50, 100]
      ],
      per_page_default: [
        doc: "The default page size number.",
        type: :integer,
        default: 15
      ],
      init_order: [
        doc:
          "Order that will be used when no other order options are given. Defaults to the primary key, ascending.",
        type: {
          :or,
          [
            {:fun, 1},
            map: [
              by: [
                doc: "The column used for ordering.",
                type: :atom
              ],
              direction: [
                doc: "The order direction",
                type: :atom
              ]
            ]
          ]
        }
      ],
      fluid?: [
        doc: "If the layout fills out the entire width.",
        type: :boolean,
        default: false
      ],
      full_text_search: [
        doc: "The name of the generated column used for full text search.",
        type: :atom,
        default: nil
      ],
      save_and_continue_button?: [
        doc: "If the \"Save & Continue editing\" button is shown on form views.",
        type: :boolean,
        default: false
      ],
      on_mount: [
        doc: """
        An optional list of hooks to attach to the mount lifecycle. Passing a single value is also accepted.
        See https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#on_mount/1
        """,
        type: {:or, [:mod_arg, :atom, {:list, {:or, [:mod_arg, :atom]}}]},
        required: false
      ]
    ],
    sections: [@fields, @filters, @item_actions]
  }

  use Spark.Dsl.Extension,
    sections: [@backpex],
    transformers: [AshBackpex.LiveResource.Transformers.GenerateBackpex]
end
