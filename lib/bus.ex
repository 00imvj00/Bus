defmodule Bus do
  use Application
  alias Bus.Supervisor

  def start(_type, args) do
    Supervisor.start_link(args)
  end
end
