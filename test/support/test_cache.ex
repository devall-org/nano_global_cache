defmodule TestCache do
  @moduledoc false
  use NanoGlobalCache

  cache :github do
    fetch fn ->
      if pid = Process.whereis(:fetch_tracker) do
        send(pid, {:fetch, :github, node()})
      end

      token = "gho_#{:rand.uniform(10000)}"
      expires_at = System.system_time(:millisecond) + 200
      {:ok, token, expires_at}
    end
  end

  cache :google do
    fetch fn ->
      if pid = Process.whereis(:fetch_tracker) do
        send(pid, {:fetch, :google, node()})
      end

      :error
    end
  end

  cache :slack do
    fetch fn ->
      if pid = Process.whereis(:fetch_tracker) do
        send(pid, {:fetch, :slack, node()})
      end

      token = "xoxb_#{:rand.uniform(10000)}"
      expires_at = System.system_time(:millisecond) + :timer.hours(1)
      {:ok, token, expires_at}
    end
  end
end
