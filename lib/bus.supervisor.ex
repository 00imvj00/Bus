defmodule Bus.Supervisor do
  use Supervisor
  require Logger

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    children = [Bus.IdProvider, {Bus.Mqtt, []}]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
