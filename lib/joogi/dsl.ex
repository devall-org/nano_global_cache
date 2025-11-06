defmodule Joogi.Dsl do
  defmodule Field do
    defstruct [:name, :fetch, :expires_in, :lazy?, :__spark_metadata__]
  end

  @field %Spark.Dsl.Entity{
    name: :field,
    args: [:name],
    target: Field,
    describe: "Schedule for refreshing data",
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "The name of the field"
      ],
      fetch: [
        type: {:fun, 0},
        required: true,
        doc: "The function to fetch the field"
      ],
      expires_in: [
        type: :pos_integer,
        required: true,
        doc: "The number of milliseconds to cache the field"
      ],
      lazy?: [
        type: :boolean,
        required: false,
        doc: "Whether the field is lazy, meaning it will be fetched on demand"
      ]
    ]
  }

  @fields %Spark.Dsl.Section{
    name: :fields,
    schema: [],
    entities: [@field],
    describe: "Fields to fetch"
  }

  use Spark.Dsl.Extension, sections: [@fields]
end
