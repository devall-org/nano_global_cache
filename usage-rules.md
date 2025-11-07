# NanoGlobalCache Usage Rules

Lightweight global cache for Elixir with expiration support. Uses Spark DSL for compile-time cache definition.

## Defining Caches

```elixir
defmodule MyApp.TokenCache do
  use NanoGlobalCache

  cache :github do
    fetch fn ->
      case GitHub.refresh_token() do
        {:ok, token} ->
          expires_at = System.system_time(:millisecond) + :timer.hours(1)
          {:ok, token, expires_at}
        :error ->
          :error
      end
    end
  end
end
```

## Generated Functions

The DSL automatically generates these functions:

```elixir
MyApp.TokenCache.fetch(:github)      # Returns {:ok, value, expires_at} or :error
MyApp.TokenCache.fetch!(:github)     # Returns value or raises
MyApp.TokenCache.clear(:github)      # Clears specific cache
MyApp.TokenCache.clear_all()         # Clears all caches
```

## Critical Rules

### Fetch Function Return Value

**MUST return exactly one of:**
- `{:ok, value, expires_at}` where `expires_at` is Unix timestamp in **milliseconds**
- `:error`

**Common mistakes to avoid:**
- Do NOT return `{:ok, value}` without expiration time
- Do NOT return `{:error, reason}` - use `:error` atom only
- Do NOT use seconds for expiration - must be milliseconds

```elixir
# CORRECT
expires_at = System.system_time(:millisecond) + :timer.hours(1)
{:ok, token, expires_at}

# CORRECT - Converting JWT exp (seconds) to milliseconds
expires_at = jwt_exp_seconds * 1000
{:ok, token, expires_at}

# WRONG - Using seconds
expires_at = System.system_time(:second) + 3600

# WRONG - Missing expiration
{:ok, token}

# WRONG - Detailed error tuple
{:error, "Token expired"}
```

### Caching Behavior

- Success results (`{:ok, value, expires_at}`) are cached until expiration
- Failure results (`:error`) are NEVER cached - fetch function is called on every attempt
- After expiration, fetch function is automatically called again
- Cache names must be compile-time atoms defined in DSL, no dynamic cache keys
