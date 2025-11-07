defmodule NanoGlobalCache do
  @moduledoc """
  A lightweight global cache for Elixir with expiration support.

  Provides compile-time DSL for defining cacheable values and runtime functions
  for fetching and managing cached data using global agents.
  """

  use Spark.Dsl, default_extensions: [extensions: [NanoGlobalCache.Dsl]]

  @doc """
  Fetch a cached value, returning `{:ok, value, expires_at}` on success or `:error` on failure.

  The cache is created on first access and automatically reused for subsequent fetches
  until the expiration time is reached. Failures are not cached and retried on each call.

  The fetch function must return `{:ok, value, expires_at}` where `expires_at` is a Unix
  timestamp in milliseconds, or `:error`.
  """
  def fetch(module, cache_name) do
    # Retrieve cache configuration (fetch function)
    %{fetch: fetch_fn} =
      NanoGlobalCache.Info.caches(module) |> Enum.find(fn cache -> cache.name == cache_name end)

    # Create a unique global identifier for this cache
    agent = {module, cache_name}

    # Use global transaction to ensure distributed concurrency-safe cache operations
    :global.trans(agent, fn ->
      case :global.whereis_name(agent) do
        # First access: fetch value and create agent to hold the entry
        :undefined ->
          {:ok, pid} = Agent.start(fetch_fn, name: {:global, agent})
          Agent.get(pid, & &1)

        # Subsequent access: check expiration and update if needed
        pid when is_pid(pid) ->
          Agent.get_and_update(pid, fn
            # Failures are never cached, always retry
            :error ->
              new_entry = fetch_fn.()
              {new_entry, new_entry}

            # Check expiration status and update if needed
            {:ok, _, expires_at} = entry ->
              now = System.system_time(:millisecond)

              if now > expires_at do
                # Expired: discard old entry and fetch fresh value
                new_entry = fetch_fn.()
                {new_entry, new_entry}
              else
                # Still valid: return cached value without updating
                {entry, entry}
              end
          end)
      end
    end)
  end

  @doc """
  Fetch a cached value, raising an exception on failure.

  Returns the cached value directly without expiration time.
  """
  def fetch!(module, cache_name) do
    case fetch(module, cache_name) do
      {:ok, value, _expires_at} -> value
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
end
