defmodule TestCache do
  @moduledoc false
  use NanoGlobalCache

  cache :github do
    fetch fn ->
      token = "gho_#{:rand.uniform(10000)}"
      expires_at = System.system_time(:millisecond) + 200
      {:ok, token, expires_at}
    end
  end

  cache :slack do
    fetch fn ->
      token = "xoxb_#{:rand.uniform(10000)}"
      expires_at = System.system_time(:millisecond) + :timer.hours(1)
      {:ok, token, expires_at}
    end
  end
end
