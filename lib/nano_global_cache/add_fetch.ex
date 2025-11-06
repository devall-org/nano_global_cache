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

         def fetch!(cache_name) do
           NanoGlobalCache.fetch!(__MODULE__, cache_name)
         end

         def clear(cache_name) do
           NanoGlobalCache.clear(__MODULE__, cache_name)
         end

         def clear_all() do
           NanoGlobalCache.clear_all(__MODULE__)
         end
       end
     )}
  end
end
