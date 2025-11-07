defmodule NanoGlobalCache.DistributedTest do
  use ExUnit.Case

  alias TestCache

  @moduletag :distributed

  setup do
    on_exit(fn ->
      TestCache.clear_all()
    end)

    :ok
  end

  describe "distributed caching" do
    test "cache is replicated across nodes" do
      nodes = ClusterHelper.start_nodes([:node2])
      [{_pid2, node2}] = nodes

      {:ok, token1, _} = TestCache.fetch(:github)
      token2 = :erpc.call(node2, TestCache, :fetch, [:github])
      assert {:ok, ^token1, _} = token2

      ClusterHelper.stop_nodes(nodes)
    end

    test "updates are synchronized across nodes" do
      nodes = ClusterHelper.start_nodes([:node2])
      [{_pid2, node2}] = nodes

      {:ok, token1, _} = TestCache.fetch(:github)
      Process.sleep(250)

      {:ok, token2, _} = TestCache.fetch(:github)
      assert token2 != token1

      {:ok, token3, _} = :erpc.call(node2, TestCache, :fetch, [:github])
      assert token3 == token2

      ClusterHelper.stop_nodes(nodes)
    end

    test "each node has local replica" do
      nodes = ClusterHelper.start_nodes([:node2])
      [{_pid2, node2}] = nodes
      group = {TestCache, :github}

      # 초기 상태: 두 노드 모두 local member 0개
      assert :pg.get_local_members(:nano_global_cache, group) == []
      local2_before = :erpc.call(node2, :pg, :get_local_members, [:nano_global_cache, group])
      assert local2_before == []

      # Node1에서 fetch
      {:ok, _, _} = TestCache.fetch(:github)

      # Node1에만 local member 생성됨
      assert length(:pg.get_local_members(:nano_global_cache, group)) == 1
      assert :erpc.call(node2, :pg, :get_local_members, [:nano_global_cache, group]) == []

      # Node2에서 fetch (복제 생성)
      :erpc.call(node2, TestCache, :fetch, [:github])

      # :pg 그룹에 2개 멤버
      assert length(:pg.get_members(:nano_global_cache, group)) == 2

      # 각 노드에 local member 1개씩
      assert length(:pg.get_local_members(:nano_global_cache, group)) == 1
      local2_after = :erpc.call(node2, :pg, :get_local_members, [:nano_global_cache, group])
      assert length(local2_after) == 1

      ClusterHelper.stop_nodes(nodes)
    end

    test "concurrent updates are safe" do
      nodes = ClusterHelper.start_nodes([:node2])
      [{_pid2, node2}] = nodes

      {:ok, _, _} = TestCache.fetch(:github)
      Process.sleep(250)

      task1 = Task.async(fn -> TestCache.fetch(:github) end)
      task2 = Task.async(fn -> :erpc.call(node2, TestCache, :fetch, [:github]) end)

      {:ok, token1, _} = Task.await(task1)
      {:ok, token2, _} = Task.await(task2)

      assert token1 == token2

      ClusterHelper.stop_nodes(nodes)
    end
  end
end
