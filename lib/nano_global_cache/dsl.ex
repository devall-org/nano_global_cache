defmodule NanoGlobalCache.Dsl do
  defmodule Cache do
    defstruct [:name, :expires_in, :run, :__spark_metadata__]
  end

  @cache %Spark.Dsl.Entity{
    name: :cache,
    args: [:name],
    target: Cache,
    describe: "A cached field that expires after a specified duration",
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "The name of the cache"
      ],
      expires_in: [
        type: :pos_integer,
        required: true,
        doc: "The number of milliseconds to cache the value"
      ],
      run: [
        type: {:fun, 0},
        required: true,
        doc: "The function to fetch the value"
      ]
    ]
  }

  @caches %Spark.Dsl.Section{
    name: :caches,
    schema: [],
    entities: [@cache],
    describe: "Define cacheable values with expiration"
  }

  use Spark.Dsl.Extension, sections: [@caches], transformers: [NanoGlobalCache.AddFetch]
end

