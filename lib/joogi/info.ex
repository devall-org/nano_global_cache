defmodule Joogi.Info do
  use Spark.InfoGenerator, extension: Joogi.Dsl, sections: [:fields]
end
