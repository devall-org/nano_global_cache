defmodule NanoGlobalCache.Dsl do
  defmodule Cache do
    defstruct [:name, :fetch, :__spark_metadata__]
  end

  @cache %Spark.Dsl.Entity{
    name: :cache,
    args: [:name],
    target: Cache,
    describe: "A cached field with custom expiration",
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "The name of the cache"
      ],
      fetch: [
        type: {:fun, 0},
        required: true,
        doc: "Function that returns {:ok, value, expires_at} or :error"
      ]
    ]
  }

  @caches %Spark.Dsl.Section{
    name: :caches,
    schema: [],
    entities: [@cache],
    top_level?: true,
    describe: "Define cacheable values with expiration"
  }

  use Spark.Dsl.Extension, sections: [@caches], transformers: [NanoGlobalCache.AddFetch]
end
