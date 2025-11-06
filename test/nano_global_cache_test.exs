defmodule NanoGlobalCacheTest do
  use ExUnit.Case
  doctest NanoGlobalCache

  defmodule Season do
    use NanoGlobalCache

    caches do
      cache :spring do
        expires_in(200)

        run(fn ->
          send(Agent.get(:cur_test, & &1), :spring)
          {:ok, :crypto.strong_rand_bytes(4)}
        end)
      end

      cache :summer do
        expires_in(200)

        run(fn ->
          send(Agent.get(:cur_test, & &1), :summer)
          :error
        end)
      end
    end
  end

  setup do
    this = self()
    Agent.start_link(fn -> this end, name: :cur_test)
    :ok
  end

  test "caches successful results until expiration" do
    refute_receive :spring
    {:ok, val1} = Season.fetch(:spring)
    assert_receive :spring

    {:ok, val2} = Season.fetch(:spring)
    # cached, no re-execution
    refute_receive :spring
    assert val1 == val2

    Process.sleep(300)

    refute_receive :spring
    {:ok, val3} = Season.fetch(:spring)
    assert_receive :spring
    assert val3 != val1
  end

  test "does not cache failures" do
    refute_receive :summer
    :error = Season.fetch(:summer)
    assert_receive :summer

    :error = Season.fetch(:summer)
    # errors are not cached
    assert_receive :summer
  end
end

