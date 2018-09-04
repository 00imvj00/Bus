defmodule Bus do
  use Application
  alias Bus.Supervisor

  @spec start(any(), any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start(_type, args) do
    Supervisor.start_link(args)
  end
end
