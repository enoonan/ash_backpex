defmodule AshBackpex.LiveResource.Info do
  @moduledoc """
  Uses Spark.InfoGenerator to generate extremely handy Spark Info modules for the AshBackpex DSL.
  """
  use Spark.InfoGenerator, extension: AshBackpex.LiveResource.Dsl, sections: [:backpex]
end
