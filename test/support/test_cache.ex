defmodule TestCache do
  @moduledoc false
  use NanoGlobalCache

  cache :github do
    fetch fn ->
      # Send message to track fetch calls
      if Process.whereis(:fetch_tracker) do
        send(:fetch_tracker, {:fetch, :github, node()})
      end

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
