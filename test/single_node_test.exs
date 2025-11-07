defmodule NanoGlobalCache.SingleNodeTest do
  use ExUnit.Case, async: false
  doctest NanoGlobalCache

  setup do
    Process.register(self(), :fetch_tracker)

    on_exit(fn ->
      TestCache.clear_all()

      if Process.whereis(:fetch_tracker) do
        Process.unregister(:fetch_tracker)
      end

      # Ensure :pg groups are cleaned
      Process.sleep(10)
    end)

    :ok
  end

  describe "fetch/1" do
    test "caches GitHub tokens until expiration" do
      now = System.system_time(:millisecond)
      {:ok, token1, expires_at1} = TestCache.fetch(:github)
      assert_receive {:fetch, :github, _}
      assert is_integer(expires_at1)
      assert expires_at1 > now

      {:ok, token2, expires_at2} = TestCache.fetch(:github)
      # cached, no re-execution (no external API call)
      refute_receive {:fetch, :github, _}
      assert token1 == token2
      assert expires_at1 == expires_at2

      Process.sleep(300)

      {:ok, token3, expires_at3} = TestCache.fetch(:github)
      assert_receive {:fetch, :github, _}
      assert token3 != token1
      assert expires_at3 > expires_at1
    end

    test "does not cache Google token refresh failures" do
      :error = TestCache.fetch(:google)
      assert_receive {:fetch, :google, _}

      :error = TestCache.fetch(:google)
      # refresh failures are retried on each call
      assert_receive {:fetch, :google, _}
    end
  end

  describe "fetch!/1" do
    test "returns GitHub token on success" do
      token = TestCache.fetch!(:github)
      assert_receive {:fetch, :github, _}
      assert String.starts_with?(token, "gho_")
    end

    test "raises on Google token refresh failure" do
      assert_raise RuntimeError, fn -> TestCache.fetch!(:google) end
      assert_receive {:fetch, :google, _}
    end
  end

  describe "clear" do
    test "removes cache before expiration" do
      {:ok, token1, _} = TestCache.fetch(:github)
      {:ok, token2, _} = TestCache.fetch(:github)
      assert token1 == token2

      TestCache.clear(:github)

      {:ok, token3, _} = TestCache.fetch(:github)
      assert token3 != token1
    end

    test "clear_all removes all caches" do
      {:ok, token1, _} = TestCache.fetch(:github)
      :error = TestCache.fetch(:google)

      TestCache.clear_all()

      {:ok, token2, _} = TestCache.fetch(:github)
      assert token2 != token1
    end
  end

  describe "supervision" do
    test "agents are added to DynamicSupervisor" do
      # Initially no children
      %{active: active_before} = DynamicSupervisor.count_children(NanoGlobalCache.Supervisor)

      # Create first cache
      {:ok, _, _} = TestCache.fetch(:github)
      %{active: active_after_1} = DynamicSupervisor.count_children(NanoGlobalCache.Supervisor)
      assert active_after_1 == active_before + 1

      # Create second cache
      {:ok, _, _} = TestCache.fetch(:slack)
      %{active: active_after_2} = DynamicSupervisor.count_children(NanoGlobalCache.Supervisor)
      assert active_after_2 == active_before + 2

      # Clear one cache
      TestCache.clear(:github)
      %{active: active_after_clear} = DynamicSupervisor.count_children(NanoGlobalCache.Supervisor)
      assert active_after_clear == active_before + 1
    end

    test "agents are added to :pg groups" do
      group_github = {TestCache, :github}
      group_slack = {TestCache, :slack}

      # Initially no members
      assert :pg.get_members(:nano_global_cache, group_github) == []
      assert :pg.get_members(:nano_global_cache, group_slack) == []

      # Create first cache
      {:ok, _, _} = TestCache.fetch(:github)
      assert length(:pg.get_members(:nano_global_cache, group_github)) == 1

      # Create second cache
      {:ok, _, _} = TestCache.fetch(:slack)
      assert length(:pg.get_members(:nano_global_cache, group_slack)) == 1

      # Clear removes from pg
      TestCache.clear(:github)
      assert :pg.get_members(:nano_global_cache, group_github) == []
      assert length(:pg.get_members(:nano_global_cache, group_slack)) == 1
    end

    test "local members are preferred" do
      group = {TestCache, :github}

      # First fetch creates local member
      {:ok, token1, expires_at1} = TestCache.fetch(:github)

      # Verify local member exists
      [_local_pid] = :pg.get_local_members(:nano_global_cache, group)

      # Second fetch should use the same local member (no fetch call)
      {:ok, token2, expires_at2} = TestCache.fetch(:github)
      assert token1 == token2
      assert expires_at1 == expires_at2
      assert_receive {:fetch, :github, _}, 100

      # No additional fetch messages (meaning it used cache)
      refute_receive {:fetch, :github, _}
    end
  end
end
