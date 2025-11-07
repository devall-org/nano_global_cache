defmodule ClusterHelper do
  @moduledoc """
  Helper for distributed node testing using :peer module.

  To run distributed tests:

      elixir --sname test -S mix test --only distributed
  """

  def start_nodes(names) do
    # Start distributed mode if not already active
    unless Node.alive?() do
      # Generate random node name to avoid conflicts
      node_name = :"test_#{:rand.uniform(999_999)}"
      {:ok, _} = :net_kernel.start([node_name, :shortnames])
      Node.set_cookie(:test_cookie)
    end

    # Start peer nodes
    Enum.map(names, fn name ->
      {:ok, pid, node} =
        :peer.start_link(%{
          name: name,
          connection: :standard_io,
          args: [~c"-setcookie", ~c"test_cookie"]
        })

      # Add code paths from current node
      :erpc.call(node, :code, :add_paths, [:code.get_path()])

      # Start application on peer node
      {:ok, _apps} = :erpc.call(node, Application, :ensure_all_started, [:nano_global_cache])

      # Compile and load test cache module on peer
      # test_cache_path = Path.expand("test/support/test_cache.ex")
      # _compiled = :erpc.call(node, Code, :compile_file, [test_cache_path])

      {pid, node}
    end)
  end

  def stop_nodes(nodes) do
    Enum.each(nodes, fn {pid, _node} ->
      :peer.stop(pid)
    end)
  end
end
