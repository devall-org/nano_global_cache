defmodule NanoGlobalCache do
  @moduledoc """
  A lightweight global cache for Elixir with expiration support.

  Provides compile-time DSL for defining cacheable values and runtime functions
  for fetching and managing cached data using global agents.
  """

  use Spark.Dsl, default_extensions: [extensions: [NanoGlobalCache.Dsl]]

  @doc """
  Fetch a cached value, returning `{:ok, value, expires_at}` on success or `:error` on failure.

  Replicated across cluster for local access. Failures are not cached and retried on each call.

  The fetch function must return `{:ok, value, expires_at}` where `expires_at` is a Unix
  timestamp in milliseconds, or `:error`.
  """
  def fetch(module, cache_name) do
    # Retrieve cache configuration
    %{fetch: fetch_fn} =
      NanoGlobalCache.Info.caches(module) |> Enum.find(fn cache -> cache.name == cache_name end)

    group = {module, cache_name}

    # Step 1: Try local agent first (lock-free fast path)
    case get_local_agent(group) do
      nil ->
        # No local agent, need to create
        acquire_lock_and_fetch(group, fetch_fn)

      local_pid ->
        # Local agent exists
        case Agent.get(local_pid, & &1) do
          :error ->
            # Failed entry, need to retry
            acquire_lock_and_fetch(group, fetch_fn)

          {:ok, _, expires_at} = entry ->
            if expired?(expires_at) do
              # Expired, need to refresh
              acquire_lock_and_fetch(group, fetch_fn)
            else
              # Valid, return immediately
              entry
            end
        end
    end
  end

  # Step 2: Acquire lock and double-check before updating
  defp acquire_lock_and_fetch(group, fetch_fn) do
    :global.trans(group, fn ->
      # Double-check: try local agent again
      case get_local_agent(group) do
        nil ->
          # Still no local agent, create it
          local_pid = create_local_agent(group, fetch_fn)
          Agent.get(local_pid, & &1)

        local_pid ->
          # Local agent exists, check again
          case Agent.get(local_pid, & &1) do
            :error ->
              # Fetch and update all members
              new_entry = fetch_fn.()
              update_all_members(group, new_entry)
              new_entry

            {:ok, _, expires_at} = entry ->
              if expired?(expires_at) do
                # Fetch and update all members
                new_entry = fetch_fn.()
                update_all_members(group, new_entry)
                new_entry
              else
                # Another process already updated it
                entry
              end
          end
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

  Stops all agent replicas across the cluster. Returns `:ok`.
  """
  def clear(module, cache_name) do
    group = {module, cache_name}

    :global.trans(group, fn ->
      group
      |> get_all_agents()
      |> Enum.each(&Agent.stop/1)
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

  # Private helpers

  defp expired?(expires_at) do
    System.system_time(:millisecond) > expires_at
  end

  defp get_local_agent(group) do
    :pg.get_local_members(:nano_global_cache, group)
    |> List.first()
  end

  defp get_all_agents(group) do
    :pg.get_members(:nano_global_cache, group)
  end

  defp create_local_agent(group, fetch_fn) do
    # Try to copy from remote member first
    initial_value =
      case :pg.get_members(:nano_global_cache, group) do
        [remote_pid | _] ->
          Agent.get(remote_pid, & &1)

        [] ->
          fetch_fn.()
      end

    spec = %{
      id: {group, node()},
      start: {Agent, :start_link, [fn -> initial_value end]},
      restart: :temporary
    }

    {:ok, pid} = DynamicSupervisor.start_child(NanoGlobalCache.Supervisor, spec)
    :ok = :pg.join(:nano_global_cache, group, pid)
    pid
  end

  defp update_all_members(group, new_entry) do
    group
    |> get_all_agents()
    |> Enum.each(fn pid ->
      Agent.update(pid, fn _ -> new_entry end)
    end)
  end
end
