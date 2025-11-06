defmodule NanoGlobalCache do
  @moduledoc """
  A lightweight global cache for Elixir with expiration support.

  Provides compile-time DSL for defining cacheable values and runtime functions
  for fetching and managing cached data using global agents.
  """

  use Spark.Dsl, default_extensions: [extensions: [NanoGlobalCache.Dsl]]

  @doc """
  Fetch a cached value, returning `{:ok, value}` on success or `:error` on failure.

  The cache is created on first access and automatically reused for subsequent fetches
  until the expiration time is reached. Failures are not cached and retried on each call.
  """
  def fetch(module, cache_name) do
    # Retrieve cache configuration (expiration time and fetch function)
    %{expires_in: expires_in, fetch: fetch_fn} =
      NanoGlobalCache.Info.caches(module) |> Enum.find(fn cache -> cache.name == cache_name end)

    # Wrap the fetch function to add timestamp for expiration tracking
    fetch_with_timestamp = fn -> fetch_fn.() |> timestamp_entry() end

    # Create a unique global identifier for this cache
    agent = {module, cache_name}

    # Use global transaction to ensure thread-safe cache operations
    :global.trans(agent, fn ->
      case :global.whereis_name(agent) do
        # First access: fetch value and create agent to hold the timestamped entry
        :undefined ->
          {:ok, pid} = Agent.start(fetch_with_timestamp, name: {:global, agent})
          Agent.get(pid, &untimestamp_entry/1)

        # Subsequent access: check expiration and update if needed
        pid when is_pid(pid) ->
          Agent.get_and_update(pid, fn
            # Failures are never cached, always retry
            :error ->
              new_entry = fetch_with_timestamp.()
              {untimestamp_entry(new_entry), new_entry}

            # Check expiration status and update if needed
            {:ok, _, timestamp} = entry ->
              elapsed = System.system_time(:millisecond) - timestamp

              if elapsed > expires_in do
                # Expired: discard old entry and fetch fresh value
                new_entry = fetch_with_timestamp.()
                {untimestamp_entry(new_entry), new_entry}
              else
                # Still valid: return cached value without updating
                {untimestamp_entry(entry), entry}
              end
          end)
      end
    end)
  end

  @doc """
  Fetch a cached value, raising an exception on failure.

  Returns the cached value directly instead of a tuple.
  """
  def fetch!(module, cache_name) do
    case fetch(module, cache_name) do
      {:ok, value} -> value
      :error -> raise "Failed to fetch cache: #{inspect(cache_name)}"
    end
  end

  @doc """
  Clear a specific cache by name.

  Stops the agent holding the cached value. Returns `:ok` if the cache
  exists and is stopped, or if the cache doesn't exist.
  """
  def clear(module, cache_name) do
    agent = {module, cache_name}

    :global.trans(agent, fn ->
      case :global.whereis_name(agent) do
        :undefined -> :ok
        pid when is_pid(pid) -> Agent.stop(pid)
      end
    end)
  end

  @doc """
  Clear all caches for a module.

  Stops all agents holding cached values for the given module.
  """
  def clear_all(module) do
    NanoGlobalCache.Info.caches(module)
    |> Enum.each(fn %{name: cache_name} ->
      NanoGlobalCache.clear(module, cache_name)
    end)
  end

  # Private helpers for timestamp management

  # Attaches current timestamp to successful results for expiration tracking
  defp timestamp_entry(:error), do: :error
  defp timestamp_entry({:ok, value}), do: {:ok, value, System.system_time(:millisecond)}

  # Removes timestamp from cached entries before returning to caller
  defp untimestamp_entry(:error), do: :error
  defp untimestamp_entry({:ok, value, _timestamp}), do: {:ok, value}
end
