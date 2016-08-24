defmodule Bus do
  use Application

  def start(_type, _args) do

    import Supervisor.Spec, warn: false

    children = [
      worker(Bus.Mqtt, []),
    ]

    opts = [strategy: :one_for_one, name: Bus.Supervisor]
    Supervisor.start_link(children, opts)

  end
end
