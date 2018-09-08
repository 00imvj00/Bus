defmodule Bus.Mqtt do
  use GenServer, restart: :transient
  require Logger

  alias ExMqtt.Message
  alias ExMqtt.Protocol.Packet

  ######### API START
  @spec start_link(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(_args) do
    state = %{
      host: Application.get_env(:bus, :host, 'localhost'),
      port: Application.get_env(:bus, :port, 1883),
      username: Application.get_env(:bus, :username, ''),
      password: Application.get_env(:bus, :password, ''),
      keep_alive: Application.get_env(:bus, :keep_alive, 120),
      client_id: Application.get_env(:bus, :client_id, 'random_id'),
      auto_reconnect: Application.get_env(:bus, :auto_reconnect, true),
      socket: nil,
      timeout: 0,
      ids: Map.new()
    }

    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  @spec stop() :: any()
  def stop() do
    GenServer.call(__MODULE__, :disconnect)
  end

  @spec publish(any(), any(), any(), any(), any()) :: :ok
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
  def handle_cast({:publish, opts}, %{socket: socket, timeout: timeout, ids: id_list} = state) do
    topic = opts |> Map.fetch!(:topic)
    msg = opts |> Map.fetch!(:message)
    dup = opts |> Map.fetch!(:dup)
    qos = opts |> Map.fetch!(:qos)
    retain = opts |> Map.fetch!(:retain)

    {message, new_state} =
      case qos do
        0 ->
          packet = Message.publish(topic, msg, dup, qos, retain)
          {packet, state}

        _ ->
          {:ok, id, new_id_list} = occupy_id(id_list, 1)
          packet = Message.publish(id, topic, msg, dup, qos, retain)
          new_state = %{state | ids: new_id_list}
          {packet, new_state}
      end

    :gen_tcp.send(socket, Packet.encode(message))
    {:noreply, new_state, timeout}
  end

  # SUBSCRIBE
  @impl true
  def handle_cast(
        {:subscribe, topics, qoses},
        %{socket: socket, timeout: timeout, ids: id_list} = state
      ) do
    with {:ok, id, new_id_list} <- occupy_id(id_list, 1),
         packet <- Message.subscribe(id, topics, qoses),
         e_packet <- Packet.encode(packet),
         :ok <- :gen_tcp.send(socket, e_packet) do
      new_state = %{state | ids: new_id_list}
      {:noreply, new_state, timeout}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # UNSUBSCRIBE
  @impl true
  def handle_cast(
        {:unsubscribe, topics},
        %{socket: socket, timeout: timeout, ids: id_list} = state
      ) do
    with {:ok, id, new_id_list} <- occupy_id(id_list, 1),
         packet <- Message.unsubscribe(id, topics),
         e_packet <- Packet.encode(packet),
         :ok <- :gen_tcp.send(socket, e_packet) do
      new_state = %{state | ids: new_id_list}
      {:noreply, new_state, timeout}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # DISCONNECT
  @impl true
  def handle_call(:disconnect, _From, %{socket: socket} = state) do
    with packet <- Message.disconnect(),
         message <- Packet.encode(packet),
         :ok <- :gen_tcp.send(socket, message),
         :ok <- :gen_tcp.close(socket) do
      {:stop, :normal, state}
    else
      {:error, reason} -> {:stop, reason, state}
    end
  end

  # RECEIVER
  @impl true
  def handle_info(
        {:tcp, _socket, data},
        %{socket: socket, timeout: timeout} = state
      ) do
    with :ok <- :inet.setopts(socket, active: :once),
         %{message: message} <- Packet.decode(data),
         {:reply, reply_message, new_state} <- handle_message(state, message),
         reply_packet <- Packet.encode(reply_message),
         :ok <- :gen_tcp.send(socket, reply_packet) do
      {:noreply, new_state, timeout}
    else
      {:noreply, new_state} -> {:noreply, new_state, timeout}
      {:error, reason} -> {:stop, reason}
    end
  end

  # RECEIVER_END

  # TIMEOUT, PING_REQ
  @impl true
  def handle_info(:timeout, %{socket: socket, timeout: timeout} = state) do
    with message <- Message.ping_request(),
         packet <- Packet.encode(message),
         :ok <- :gen_tcp.send(socket, packet) do
      {:noreply, state, timeout}
    else
      {:error, reason} -> {:stop, reason, state}
    end
  end

  # DISCONNECT, #END_OF_PROCESS
  @impl true
  def handle_info({:tcp_closed, socket}, %{socket: socket} = state) do
    {:stop, :nornal, state}
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

  #### This will return updated map.
  defp free_id(state, id) do
    Map.delete(state, id)
  end

  #### Get next available ID
  defp occupy_id(state, pos) when is_integer(pos) do
    cond do
      pos > 65535 ->
        {:error, "Reached at maximum."}

      true ->
        case Map.get(state, pos) do
          nil ->
            new_state = Map.put(state, pos, true)
            {:ok, pos, new_state}

          _val ->
            occupy_id(state, pos + 1)
        end
    end
  end

  # Process the packet.
  defp handle_message(%{ids: id_list} = state, message) do
    case message do
      %Message.ConnAck{} ->
        Logger.info("Mqtt Connected.")
        {:noreply, state}

      %Message.Publish{id: id, topic: topic, message: msg, qos: qos} ->
        Logger.info("Received new message. #{msg} for topic #{topic}")

        case qos do
          1 ->
            pub_ack = Message.publish_ack(id)
            {:reply, pub_ack, state}

          2 ->
            pub_rec = Message.publish_receive(id)
            {:reply, pub_rec, state}

          _ ->
            :ok
        end

      # this will only call when QoS = 1, we need to free the id.
      %Message.PubAck{id: id} ->
        new_list = free_id(id_list, id)
        new_state = %{state | ids: new_list}
        Logger.info("Publish successful.")
        {:noreply, new_state}

      # this will only call when QoS = 2
      %Message.PubRec{id: id} ->
        pub_rel_msg = Message.publish_release(id)
        {:reply, pub_rel_msg, state}

      %Message.PubRel{id: id} ->
        pub_comp_msg = Message.publish_complete(id)
        {:reply, pub_comp_msg, state}

      # this will only call when QoS = 2
      %Message.PubComp{id: id} ->
        new_list = free_id(id_list, id)
        new_state = %{state | ids: new_list}
        {:noreply, new_state}

      %Message.SubAck{id: id} ->
        new_list = free_id(id_list, id)
        new_state = %{state | ids: new_list}
        Logger.info("Subscription successful.")
        {:noreply, new_state}

      %Message.UnsubAck{id: id} ->
        new_list = free_id(id_list, id)
        new_state = %{state | ids: new_list}
        Logger.info("Unsubscribe successful.")
        {:noreply, new_state}

      %Message.PingResp{} ->
        Logger.info("Ping response received.")
        {:noreply, state}

      err ->
        Logger.error("Unknown Packet Received.")
        IO.inspect(err)
        {:error, err}
    end
  end
end
