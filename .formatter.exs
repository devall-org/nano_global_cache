# Used by "mix format"
spark_locals_without_parens = [cache: 1, cache: 2, expires_in: 1, fetch: 1]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  plugins: [Spark.Formatter],
  locals_without_parens: spark_locals_without_parens,
  export: [locals_without_parens: spark_locals_without_parens]
]
