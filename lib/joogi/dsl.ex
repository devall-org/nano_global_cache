defmodule Joogi.Dsl do
  defmodule Field do
    defstruct [:name, :expires_in, :run, :__spark_metadata__]
  end

  @field %Spark.Dsl.Entity{
    name: :field,
    args: [:name],
    target: Field,
    describe: "A cached field that expires after a specified duration",
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "The name of the field"
      ],
      expires_in: [
        type: :pos_integer,
        required: true,
        doc: "The number of milliseconds to cache the field"
      ],
      run: [
        type: {:fun, 0},
        required: true,
        doc: "The function to fetch the field"
      ]
    ]
  }

  @fields %Spark.Dsl.Section{
    name: :fields,
    schema: [],
    entities: [@field],
    describe: "Define cacheable fields with expiration"
  }

  use Spark.Dsl.Extension, sections: [@fields], transformers: [Joogi.AddFetch]
end
