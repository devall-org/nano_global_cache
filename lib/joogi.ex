defmodule Joogi do
  use Spark.Dsl, default_extensions: [extensions: [Joogi.Dsl]]

  def fetch(module, field_name) do
    %{expires_in: expires_in, run: run} =
      Joogi.Info.fields(module) |> Enum.find(fn field -> field.name == field_name end)

    run_with_timestamp = fn -> run.() |> add_timestamp() end
    agent = {module, field_name}

    :global.trans(agent, fn ->
      case :global.whereis_name(agent) do
        :undefined ->
          {:ok, pid} = Agent.start(run_with_timestamp, name: {:global, agent})
          Agent.get(pid, &remove_timestamp/1)

        pid when is_pid(pid) ->
          :ok =
            Agent.update(pid, fn
              :error ->
                run_with_timestamp.()

              {:ok, value, timestamp} ->
                if System.system_time(:millisecond) - timestamp > expires_in do
                  run_with_timestamp.()
                else
                  {:ok, value, timestamp}
                end
            end)

          Agent.get(pid, &remove_timestamp/1)
      end
    end)
  end

  defp add_timestamp(value) do
    case value do
      :error -> :error
      {:ok, value} -> {:ok, value, System.system_time(:millisecond)}
    end
  end

  defp remove_timestamp(value) do
    case value do
      :error -> :error
      {:ok, value, _timestamp} -> {:ok, value}
    end
  end
end
