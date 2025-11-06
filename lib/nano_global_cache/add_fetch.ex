defmodule NanoGlobalCache.AddFetch do
  use Spark.Dsl.Transformer

  @impl true
  def transform(dsl_state) do
    {:ok,
     dsl_state
     |> Spark.Dsl.Transformer.eval(
       [],
       quote do
         def fetch(cache_name) do
           NanoGlobalCache.fetch(__MODULE__, cache_name)
         end
       end
     )}
  end
end

