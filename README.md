# NanoGlobalCache

🔒 **Lightweight global cache for Elixir** with expiration support and intelligent failure handling.

Perfect for caching OAuth tokens, API keys, and other time-sensitive data that shouldn't be repeatedly refreshed.

## Why NanoGlobalCache?

- ✅ **Smart caching**: Caches successes, retries failures on next fetch
- 🌍 **Global**: Shared across entire Erlang node
- 🔐 **Thread-safe**: Safe concurrent access via `:global.trans/2`
- ⏱️ **Expiration**: Time-based invalidation
- 📝 **Clean DSL**: Compile-time configuration with auto-generated functions
- ⚡ **Minimal overhead**: No background processes or setup

## Installation

```elixir
def deps do
  [{:nano_global_cache, "~> 0.1.0"}]
end
```

## Quick Example

```elixir
defmodule MyApp.TokenCache do
  use NanoGlobalCache

  cache :github do
    expires_in :timer.hours(1)
    fetch fn ->
      case GitHub.refresh_token() do
        {:ok, token} -> {:ok, token}
        :error -> :error
      end
    end
  end

  cache :slack do
    expires_in :timer.minutes(30)
    fetch fn -> SlackAPI.get_token() end
  end

  # Generated functions: fetch/1, fetch!/1, clear/1, clear_all/0
end
```

### Usage

```elixir
# Pattern match on result with timestamp
{:ok, token, timestamp} = MyApp.TokenCache.fetch(:github)

# Or use bang version (no timestamp)
token = MyApp.TokenCache.fetch!(:github)

# Clear cache
MyApp.TokenCache.clear(:github)
MyApp.TokenCache.clear_all()
```

## How It Works

- **Successful results**: Cached with timestamp, returned until expiration
- **Failed results** (`:error`): Never cached, always retried on next call
- **Thread safety**: All operations use global Erlang transactions (`global.trans/2`)

## When to Use

This library is optimized for **lightweight data** like:
- OAuth tokens, API keys, JWT tokens
- Small configuration values
- Session identifiers
- Cached credentials

**NOT recommended for**:
- Large binary data (images, files, documents)
- High-frequency writes
- Performance-critical caching needs

NanoGlobalCache uses `:global` and `Agent` for simplicity and minimal overhead. It's designed for scenarios where performance impact is negligible and simplicity is valued over throughput.

## API Reference

### Define Caches
```elixir
cache :cache_name do
  expires_in milliseconds_to_expire
  fetch fn -> {:ok, value} or :error end
end
```

### Generated Functions
- `fetch(name)` → `{:ok, value, timestamp}` or `:error`
- `fetch!(name)` → `value` (without timestamp) or raises `RuntimeError`
- `clear(name)` → `:ok`
- `clear_all()` → `:ok`

## Implementation

- Spark DSL for compile-time configuration
- Erlang global agents for distributed storage
- Automatic function generation via transformers
