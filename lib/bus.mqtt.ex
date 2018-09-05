defmodule Bus.Mqtt do
  use GenServer, restart: :transient
  require Logger

  alias ExMqtt.Message
  alias ExMqtt.Protocol.Packet
  alias Bus.IdProvider

  @initial_state %{
    socket: nil,
    timeout: 0,
    host: 'localhost',
    port: 1883,
    keep_alive: 120,
    username: "",
    password: "",
    client_id: "1",
    auto_reconnect: true
  }

  ######### API START
  def start_link(_args) do
    GenServer.start_link(__MODULE__, @initial_state, name: __MODULE__)
  end

  def stop() do
    GenServer.call(__MODULE__, :disconnect)
  end

  def publish(topic, message, qos \\ 1, dup \\ 0, retain \\ 0) do
    opts = %{
      topic: topic,
      message: message,
      dup: dup,
      qos: qos,
      retain: retain
    }

    GenServer.cast(__MODULE__, {:publish, opts})
  end

  # list_of_data = [{topic,qos},{topic,qos}]
  def subscribe(topics, qoses) do
    GenServer.cast(__MODULE__, {:subscribe, topics, qoses})
  end

  # check if arg is list or not.
  def unsubscribe(list_of_topics) do
    GenServer.cast(__MODULE__, {:unsubscribe, list_of_topics})
  end

  ########### APIS END

  # GEN_SERVER
  # CONNECT
  @impl true
  def init(state) do
    will_topic = ""
    will_message = ""
    will_qos = 0
    will_retain = 0
    clean_session = 1
    keep_alive = Map.get(state, :keep_alive)

    message =
      Message.connect(
        Map.get(state, :client_id),
        Map.get(state, :username),
        Map.get(state, :password),
        will_topic,
        will_message,
        will_qos,
        will_retain,
        clean_session,
        keep_alive
      )

    timeout = get_timeout(keep_alive)
    tcp_opts = [:binary, active: :once]
    # milliseconds
    tcp_time_out = 10_000
    host = Map.get(state, :host)
    port = Map.get(state, :port)

    case :gen_tcp.connect(host, port, tcp_opts, tcp_time_out) do
      {:ok, socket} ->
        case :gen_tcp.send(socket, Packet.encode(message)) do
          :ok -> :ok
          {:error, reason} -> {:error, reason}
        end

        new_state = %{state | socket: socket, timeout: timeout}
        {:ok, new_state, timeout}

      {:error, reason} ->
        Logger.info("Error while connecting to TCP")
        {:error, reason}
    end
  end

  # PUBLISH
  @impl true
  def handle_cast({:publish, opts}, %{socket: socket, timeout: timeout} = state) do
    # ""
    topic = opts |> Map.fetch!(:topic)
    # ""
    msg = opts |> Map.fetch!(:message)
    # bool
    dup = opts |> Map.fetch!(:dup)
    # int
    qos = opts |> Map.fetch!(:qos)
    # bool
    retain = opts |> Map.fetch!(:retain)

    message =
      case qos do
        0 ->
          Message.publish(topic, msg, dup, qos, retain)

        _ ->
          id = IdProvider.get_id(true)
          Message.publish(id, topic, msg, dup, qos, retain)
      end

    :gen_tcp.send(socket, Packet.encode(message))
    {:noreply, state, timeout}
  end

  # SUBSCRIBE
  @impl true
  def handle_cast({:subscribe, topics, qoses}, %{socket: socket, timeout: timeout} = state) do
    id = IdProvider.get_id(:a)
    message = Message.subscribe(id, topics, qoses)
    :gen_tcp.send(socket, Packet.encode(message))
    {:noreply, state, timeout}
  end

  # UNSUBSCRIBE
  @impl true
  def handle_cast({:unsubscribe, topics}, %{socket: socket, timeout: timeout} = state) do
    id = IdProvider.get_id(true)
    message = Message.unsubscribe(id, topics)
    :gen_tcp.send(socket, Packet.encode(message))
    {:noreply, state, timeout}
  end

  # DISCONNECT
  @impl true
  def handle_call(:disconnect, _From, %{socket: socket} = state) do
    message = Message.disconnect()

    case :gen_tcp.send(socket, Packet.encode(message)) do
      :ok -> Logger.info("Disconnect packet sent.")
      {:error, reason} -> Logger.info("Error while sending Disconnect packet. Reason #{reason}")
    end

    :ok = :gen_tcp.close(socket)
    {:stop, :normal, state}
  end

  # RECEIVER
  @impl true
  def handle_info(
        {:tcp, _socket, msg},
        %{socket: socket, timeout: timeout} = state
      ) do
    :inet.setopts(socket, active: :once)
    %{message: message} = Packet.decode(msg)

    case message do
      %Message.ConnAck{} ->
        Logger.info("Mqtt Connected.")

      %Message.Publish{id: id, topic: topic, message: msg, qos: qos} ->
        Logger.info("Received new message. #{msg} for topic #{topic}")

        case qos do
          1 ->
            pub_ack = Message.publish_ack(id)
            :gen_tcp.send(socket, Packet.encode(pub_ack))

          2 ->
            pub_rec = Message.publish_receive(id)
            :gen_tcp.send(socket, Packet.encode(pub_rec))

          _ ->
            :ok
        end

      # this will only call when QoS = 1, we need to free the id.
      %Message.PubAck{id: id} ->
        IdProvider.free_id(id)
        Logger.info("Publish successful.")

      # this will only call when QoS = 2
      %Message.PubRec{id: id} ->
        pub_rel_msg = Message.publish_release(id)
        :gen_tcp.send(socket, Packet.encode(pub_rel_msg))

      %Message.PubRel{id: id} ->
        pub_comp_msg = Message.publish_complete(id)
        :gen_tcp.send(socket, Packet.encode(pub_comp_msg))

      # this will only call when QoS = 2
      %Message.PubComp{id: id} ->
        IdProvider.free_id(id)

      %Message.SubAck{id: id} ->
        IdProvider.free_id(id)
        Logger.info("Subscription successful.")

      %Message.UnsubAck{id: id} ->
        IdProvider.free_id(id)
        Logger.info("Unsubscribe successful.")

      # this is internal use.increase the timeout.
      %Message.PingResp{} ->
        :ok

      Err ->
        Logger.error("Unknown Packet Received.")
        IO.inspect(Err)
    end

    {:noreply, state, timeout}
  end

  # RECEIVER_END

  # TIMEOUT, PING_REQ
  @impl true
  def handle_info(:timeout, %{socket: socket, timeout: timeout} = state) do
    message = Message.ping_request()
    :gen_tcp.send(socket, Packet.encode(message))
    {:noreply, state, timeout}
  end

  # DISCONNECT, #END_OF_PROCESS
  @impl true
  def handle_info({:tcp_closed, socket}, %{socket: socket} = state) do
    {:stop, "TCP connection closed.", state}
  end

  # END_OF_PROCESS
  @impl true
  def terminate(_reason, _state) do
    Logger.info("Gen Server terminated.")
    :ok
  end

  # GEN_SERVER : END
  defp get_timeout(keep_alive) do
    if keep_alive == 0 do
      :infinity
    else
      # we will send pingreq before 5 sec of timeout.
      (keep_alive - 5) * 1000
    end
  end
end
