defmodule NanoGlobalCache.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {DynamicSupervisor, name: NanoGlobalCache.Supervisor, strategy: :one_for_one}
    ]

    opts = [strategy: :one_for_one, name: NanoGlobalCache.ApplicationSupervisor]
    Supervisor.start_link(children, opts)
  end
end
