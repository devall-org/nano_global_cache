# NanoGlobalCache

🔒 **Lightweight global cache for Elixir** with expiration support and intelligent failure handling.

Perfect for caching OAuth tokens, API keys, and other time-sensitive data that shouldn't be repeatedly refreshed.

## Why NanoGlobalCache?

- ✅ **Smart caching**: Caches successes, retries failures on next fetch
- 🌍 **Distributed**: Shared across entire Erlang cluster
- 🔐 **Concurrency-safe**: Safe concurrent access via `:global.trans/2`
- ⏱️ **Expiration**: Time-based invalidation
- 📝 **Clean DSL**: [Spark](https://github.com/ash-project/spark)-based compile-time configuration with auto-generated functions
- ⚡ **Minimal overhead**: No background processes or setup

## Installation

```elixir
def deps do
  [{:nano_global_cache, "~> 0.2.0"}]
end
```

## Quick Example

```elixir
defmodule MyApp.TokenCache do
  use NanoGlobalCache

  # Regular OAuth token - calculate expiration yourself
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

  # JWT token - use expiration time from the token itself
  cache :auth0 do
    fetch fn ->
      case Auth0.get_access_token() do
        {:ok, jwt} ->
          # JWT exp claim is in seconds, convert to milliseconds
          %{"exp" => exp_seconds} = JOSE.JWT.peek_payload(jwt)
          expires_at = exp_seconds * 1000
          {:ok, jwt, expires_at}
        :error ->
          :error
      end
    end
  end

  # Generated functions: fetch/1, fetch!/1, clear/1, clear_all/0
end
```

### Usage

```elixir
# Pattern match on result with expiration time
{:ok, token, expires_at} = MyApp.TokenCache.fetch(:github)

# Or use bang version (no expiration time)
token = MyApp.TokenCache.fetch!(:github)

# Clear cache
MyApp.TokenCache.clear(:github)
MyApp.TokenCache.clear_all()
```

## How It Works

- **Successful results**: Cached with expiration time, returned until expiration
- **Failed results** (`:error`): Never cached, always retried on next call
- **Distributed concurrency**: All operations use global Erlang transactions (`global.trans/2`) for safe access across nodes

## When to Use

This library is optimized for **lightweight data** like:
- OAuth tokens, API keys, JWT tokens
- Small configuration values
- Session identifiers
- Cached credentials

**NOT recommended for**:
- High-traffic scenarios (frequent reads/writes)
- Dynamic cache keys (unbounded number of entries)
- Large cache values that would cause heavy network traffic between nodes

NanoGlobalCache uses `:global` and `Agent` for simplicity and minimal overhead. Each cache lives on a single node without replication - other nodes access it remotely. It's designed for scenarios where performance impact is negligible and simplicity is valued over throughput.

**For more demanding use cases**, consider [Cachex](https://github.com/whitfin/cachex) or [Nebulex](https://github.com/cabol/nebulex).

## API Reference

### Define Caches
```elixir
cache :cache_name do
  fetch fn ->
    # Your fetch logic here
    # Must return {:ok, value, expires_at} or :error
    # expires_at is Unix timestamp in milliseconds
    {:ok, value, System.system_time(:millisecond) + ttl_milliseconds}
  end
end
```

### Generated Functions
- `fetch(name)` → `{:ok, value, expires_at}` or `:error`
- `fetch!(name)` → `value` (without expiration time) or raises `RuntimeError`
- `clear(name)` → `:ok`
- `clear_all()` → `:ok`

## Implementation

- [Spark](https://github.com/ash-project/spark) DSL for compile-time configuration
- Erlang global agents for distributed storage
- Automatic function generation via transformers
