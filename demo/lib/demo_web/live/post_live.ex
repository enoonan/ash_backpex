defmodule DemoWeb.PostLive do
  use AshBackpex.LiveResource

  backpex do
    resource(Demo.Blog.Post)
    layout({DemoWeb.Layouts, :admin})

    load([:word_count])

    fields do
      field(:title)

      field :content do
        module(Backpex.Fields.Textarea)
      end

      field(:published)

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
