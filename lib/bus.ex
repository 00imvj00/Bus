defmodule Bus do
  use Application
  alias Bus.Supervisor
  require Logger

  @spec start(any(), any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start(_type, args) do
    Logger.info("Starting Application,")
    Supervisor.start_link(args)
  end
end
