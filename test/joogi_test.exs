defmodule JoogiTest do
  use ExUnit.Case
  doctest Joogi

  defmodule Season do
    use Joogi

    fields do
      field :spring do
        fetch(fn ->
          send(self(), :spring)
          {:ok, :crypto.strong_rand_bytes(4)}
        end)

        expires_in(200)
        lazy?(false)
      end

      field :summer do
        fetch(fn ->
          send(self(), :spring)
          {:ok, :crypto.strong_rand_bytes(4)}
        end)

        expires_in(200)
        lazy?(true)
      end

      field :autumn do
        fetch(fn ->
          send(self(), :autumn)
          :error
        end)

        expires_in(200)
        lazy?(false)
      end

      field :winter do
        fetch(fn ->
          send(self(), :summer)
          :error
        end)

        expires_in(200)
        lazy?(true)
      end
    end
  end

  describe "lazy? false" do
    test "when fetch succeeds" do
      assert_receive :spring
      refute_receive :spring

      {:ok, val1} = Season.fetch(:spring)
      {:ok, val2} = Season.fetch(:spring)

      assert val1 == val2

      Process.sleep(300)

      assert_receive :spring
      refute_receive :spring

      {:ok, val3} = Season.fetch(:spring)
      assert val3 != val1
    end

    test "when fetch fails" do
      assert_receive :summer
      refute_receive :summer

      :error = Season.fetch(:summer)

      Process.sleep(300)

      assert_receive :summer
      refute_receive :summer

      :error = Season.fetch(:summer)
    end
  end

  describe "lazy? true" do
    test "when fetch succeeds" do
      refute_receive :autumn
      {:ok, val1} = Season.fetch(:autumn)
      assert_receive :autumn

      {:ok, val2} = Season.fetch(:autumn)
      refute_receive :autumn
      assert val1 == val2

      Process.sleep(300)

      refute_receive :autumn
      {:ok, val3} = Season.fetch(:autumn)
      assert_receive :autumn
      assert val3 != val1
    end

    test "when fetch fails" do
      refute_receive :winter
      :error = Season.fetch(:winter)
      assert_receive :winter

      :error = Season.fetch(:winter)
      refute_receive :winter

      Process.sleep(300)

      refute_receive :winter
      :error = Season.fetch(:winter)
      assert_receive :winter
    end
  end
end
