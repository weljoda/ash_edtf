# Used by "mix format"
[
  import_deps: [:ash, :ash_postgres, :spark],
  plugins: [Spark.Formatter],
  line_length: 120,
  inputs: ["{mix,.formatter}.exs", "{config,lib,test,priv}/**/*.{ex,exs}"]
]
