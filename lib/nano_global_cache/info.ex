defmodule NanoGlobalCache.Info do
  use Spark.InfoGenerator, extension: NanoGlobalCache.Dsl, sections: [:caches]
end
