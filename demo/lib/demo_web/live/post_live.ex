defmodule DemoWeb.PostLive do
  use AshBackpex.LiveResource

  backpex do
    resource(Demo.Blog.Post)
    layout &DemoWeb.Layouts.admin/1
    init_order %{by: :inserted_at, direction: :desc}
    load([:word_count])

    fields do
      field(:title) do
        searchable true
      end

      field :content do
        module(Backpex.Fields.Textarea)
        searchable true
      end

      field(:published)

      field :rating

      field :word_count do
        except([:new, :edit])
      end

      field :inserted_at do
        label("Created At")
        except([:new, :edit])
      end

      field :updated_at do
        label("Updated At")
        except([:new, :edit])
      end
    end
  end
end
