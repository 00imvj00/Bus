defmodule Bus do
  use Application
  alias Bus.Supervisor

  ### Application callback START

  @spec start(any(), any()) :: {:error, any()} | {:ok, pid()}
  def start(_type, args) do
    Supervisor.start_link(args)
  end

  ### Application callback END
  ##### API START

  @spec publish(any(), any(), any()) :: :ok | {:error, any()}
  def publish(topic, message, qos \\ 0) do
    Bus.Mqtt.publish(topic, message, qos)
    :ok
  end

  @spec subscribe(any(), any()) :: :ok | {:error, any()}
  def subscribe(topics, qoses) do
    Bus.Mqtt.subscribe(topics, qoses)
  end

  @spec unsubscribe(any()) :: :ok | {:error, any()}
  def unsubscribe(topics) do
    Bus.Mqtt.unsubscribe(topics)
  end

  @spec disconnect() :: any()
  def disconnect() do
    Bus.Mqtt.stop()
  end

  #### API END
end
