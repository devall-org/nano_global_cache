defmodule NanoGlobalCache.DistributedTest do
  use ExUnit.Case, async: false

  @moduletag :distributed

  setup do
    nodes = ClusterHelper.start_nodes([:node2])
    [{_pid2, node2}] = nodes

    on_exit(fn ->
      TestCache.clear_all()
      ClusterHelper.stop_nodes(nodes)
    end)

    {:ok, node2: node2}
  end

  describe "distributed caching" do
    test "cache is replicated across nodes", %{node2: node2} do
      {:ok, token1, _} = TestCache.fetch(:github)
      {:ok, token2, _} = :erpc.call(node2, TestCache, :fetch, [:github])
      assert token1 == token2
    end

    test "updates are synchronized across nodes", %{node2: node2} do
      {:ok, token1, _} = TestCache.fetch(:github)
      Process.sleep(250)

      {:ok, token2, _} = TestCache.fetch(:github)
      assert token2 != token1

      {:ok, token3, _} = :erpc.call(node2, TestCache, :fetch, [:github])
      assert token3 == token2
    end

    test "each node has local replica", %{node2: node2} do
      group = {TestCache, :github}

      # Initial state: no local members on both nodes
      assert :pg.get_local_members(:nano_global_cache, group) == []
      local2_before = :erpc.call(node2, :pg, :get_local_members, [:nano_global_cache, group])
      assert local2_before == []

      # Fetch from node1
      {:ok, _, _} = TestCache.fetch(:github)

      # Local member created only on node1
      assert length(:pg.get_local_members(:nano_global_cache, group)) == 1
      assert :erpc.call(node2, :pg, :get_local_members, [:nano_global_cache, group]) == []

      # Fetch from node2 (creates replica)
      :erpc.call(node2, TestCache, :fetch, [:github])

      # 2 members in :pg group
      assert length(:pg.get_members(:nano_global_cache, group)) == 2

      # Each node has 1 local member
      assert length(:pg.get_local_members(:nano_global_cache, group)) == 1
      local2_after = :erpc.call(node2, :pg, :get_local_members, [:nano_global_cache, group])
      assert length(local2_after) == 1
    end

    test "concurrent updates are safe", %{node2: node2} do
      # Register tracker to count fetch calls
      Process.register(self(), :fetch_tracker)

      {:ok, _, _} = TestCache.fetch(:github)
      assert_receive {:fetch, :github, _}, 100

      Process.sleep(250)

      # Concurrent fetch from both nodes
      task1 = Task.async(fn -> TestCache.fetch(:github) end)
      task2 = Task.async(fn -> :erpc.call(node2, TestCache, :fetch, [:github]) end)

      {:ok, token1, _} = Task.await(task1)
      {:ok, token2, _} = Task.await(task2)

      # Same token (same fetch result)
      assert token1 == token2

      # Only one fetch was executed despite concurrent requests
      assert_receive {:fetch, :github, _}, 100
      refute_receive {:fetch, :github, _}, 100

      Process.unregister(:fetch_tracker)
    end
  end
end
