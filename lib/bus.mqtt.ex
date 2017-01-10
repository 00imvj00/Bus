defmodule Bus.Mqtt do
	 use GenServer
     require Logger

     alias Bus.Message
     alias Bus.Protocol.Packet
     alias Bus.IdProvider
        

     @callback init(opts :: term) :: atom
     @callback connect()          :: atom | {:stop, reason:: any}
     @callback disconnect()       :: atom
     @callback message()          :: atom

     #if possible, add Id provider map here only in this state.
     #then it will be so independent of other process.
     @initial_state %{
        socket: nil, #to send & receive data
        timeout: 0,  #mqtt keep_alive timeout
        auto_reconnect: false, #reconnect auto,if disconnect.
        disconnected: true,
        host: "localhost",
        port: 1883,
        keep_alive: 0,
        username: "",
        password: "",
        client_id: "default",
        module: nil
    }

     @spec start_link(module :: term,
                      args   :: term,
                             [host:       String.t, 
                             port:      non_neg_integer,
                             client_id: String.t,
                             username:  String.t,
                             password:  String.t,
                             keep_alive: non_neg_integer
                             ]) :: {:ok,status::term} | {:error, reason::term} 
     def start_link(module,args,opts \\ []) do
          
          host       = Keyword.get(opts, :host,Map.get(@initial_state,:host))
          port       = Keyword.get(opts, :port,Map.get(@initial_state,:port))
          client_id  = Keyword.get(opts, :client_id,Map.get(@initial_state,:client_id))
          keep_alive = Keyword.get(opts, :keep_alive,Map.get(@initial_state,:keep_alive))
          username   = Keyword.get(opts, :username,Map.get(@initial_state,:username))
          password   = Keyword.get(opts, :password,Map.get(@initial_state,:password))

          state  =  %{@initial_state | 
                     module: module, host: host,
                     port: port,client_id: client_id,
                     keep_alive: keep_alive,username: username,
                     password: password
                     }
          module.init(args)
          GenServer.start_link(__MODULE__,state,[name: __MODULE__])
     end

     def stop() do
         GenServer.call( __MODULE__ , :disconnect)
     end
     
     def disconnect() do
	  	GenServer.call( __MODULE__ , :disconnect)
	 end

     def publish(topic,message,funn,qos \\ 1, dup \\ 0,retain \\ 0) do
	  	opts = %{
	  		topic: topic,
	  		message: message,
	  		dup: dup,
	  		qos: qos,
	  		retain: retain,
            cb: funn
	  	}
	  	GenServer.call( __MODULE__ , { :publish , opts })
	  end

       # list_of_data = [{topic,qos},{topic,qos}]
	  def subscribe(topics,qoses, funn) do
	  	GenServer.cast( __MODULE__ , { :subscribe , topics,qoses, funn})
	  end

    #check if arg is list or not.
	  def unsubscribe(list_of_topics, funn) do
	  	GenServer.cast( __MODULE__ , { :unsubscribe , list_of_topics, funn})
	  end

     
     #INBUILT CALLBACKS : START
     defmacro __using__(_) do
        quote location: :keep do
              @behaviour Bus.Mqtt

        def init(args) do
            {:ok, args}
        end

        def connect() do
            {:ok}
        end

        def disconnect() do
            {:ok}
        end

        def message(topic,msg) do
            {:ok,topic,msg}
        end
        
        defoverridable [init: 1, connect: 0, disconnect: 0, message: 2]
        end
     end
     #INBUILT CALLBACKS : END

      #GEN_SERVER
      #CONNECT
      def init(state) do
                    will_topic = ""
                    will_message = ""
                    will_qos = 0
                    will_retain = 0
                    clean_session = 1
                    keep_alive = Map.get(state,:keep_alive)

                    message = Message.connect(Map.get(state,:client_id),
                                            Map.get(state,:username),
                                            Map.get(state,:password),
                                            will_topic, 
                                            will_message,
                                            will_qos,
                                            will_retain,
                                            clean_session, 
                                            keep_alive)

                    timeout = get_timeout(keep_alive)

                    tcp_opts = [:binary, active: :once]
                    tcp_time_out = 10_000 #milliseconds

                    case :gen_tcp.connect(  Map.get(state,:host),
                                            Map.get(state,:port), 
                                            tcp_opts,tcp_time_out) do
                        {:ok, socket}    ->
                            :gen_tcp.send(socket,Packet.encode(message))
                             new_state = %{state | socket: socket,timeout: timeout}
                            {:ok, new_state}
                        Error   -> {:error,Error}

                    end
      end

      #PUBLISH
  	  def handle_call({:publish, opts}, _From,%{socket: socket, timeout: timeout} = state) do
            
            topic  = opts |> Map.fetch!(:topic) #""
            msg    = opts |> Map.fetch!(:message) #""
            dup    = opts |> Map.fetch!(:dup) #bool
            qos    = opts |> Map.fetch!(:qos) #int
            retain = opts |> Map.fetch!(:retain) #bool
            funn   = opts |> Map.fetch!(:cb)

            message =
            case qos do
                0 -> Message.publish(topic, msg, dup, qos, retain)
                _ ->
                    id = IdProvider.get_id(funn)
                    Message.publish(id, topic, msg, dup, qos, retain)
            end

            :gen_tcp.send(socket,Packet.encode(message))
            {:noreply, state,timeout}
      end

      #SUBSCRIBE
      def handle_call({:subscribe,topics,qoses, funn}, %{socket: socket, timeout: timeout} = state) do   
        id     = IdProvider.get_id(funn)
        message = Message.subscribe(id, topics, qoses)
    	  :gen_tcp.send(socket,Packet.encode(message))
        {:noreply, state ,timeout}
      end

      #UNSUBSCRIBE
      def handle_call({:unsubscribe, topics, funn}, %{socket: socket,timeout: timeout} = state) do
        id      = IdProvider.get_id(funn)
        message = Message.unsubscribe(id, topics)
        :gen_tcp.send(socket,Packet.encode(message))
        {:noreply, state,timeout}
      end

      #DISCONNECT
      def handle_cast(:disconnect, %{socket: socket} = state) do
        message = Message.disconnect
        :gen_tcp.send(socket,Packet.encode(message))
        :ok = :gen_tcp.close(socket)
        {:stop, :normal, state}
      end
          
     #RECEIVER
  	 def handle_info({:tcp, socket, msg}, %{socket: socket,timeout: timeout,module: module} = state) do
      :inet.setopts(socket, active: :once)
      %{message: message} = Packet.decode msg
  	 	case message do
                %Bus.Message.ConnAck{}  -> module.connect()
                %Bus.Message.Publish{id: id,topic: topic,message: msg,qos: qos} -> 
                    case qos do
                    1 -> 
                        pub_ack = Message.publish_ack(id)
                        :gen_tcp.send(socket,Packet.encode(pub_ack))
                    2 ->
                        pub_rec = Message.publish_receive(id)
                        :gen_tcp.send(socket,Packet.encode(pub_rec))
                    _ -> 
                        :ok
                    end
                    module.message(topic,msg)
                %Bus.Message.PubAck{id: id} -> #this will only call when QoS = 1, we need to free the id.
                    cb = IdProvider.free_id(id)
                    cb.()
                %Bus.Message.PubRec{id: id} -> #this will only call when QoS = 2
                    pub_rel_msg = Message.publish_release(id)
                    :gen_tcp.send(socket,Packet.encode(pub_rel_msg))
                %Bus.Message.PubRel{id: id} ->
                    pub_comp_msg = Message.publish_complete(id)
                    :gen_tcp.send(socket,Packet.encode(pub_comp_msg))
                %Bus.Message.PubComp{id: id} -> #this will only call when QoS = 2
                    cb = IdProvider.free_id(id)
                    cb.()
                %Bus.Message.SubAck{id: id} ->
                    cb = IdProvider.free_id(id)
                    cb.()
                %Bus.Message.UnsubAck{id: id} ->
                    cb = IdProvider.free_id(id)
                    cb.()
                %Bus.Message.PingResp{} -> :ok #this is internal use.increase the timeout.
                Err ->
                    Logger.error "Unknown Packet Received."
                    IO.inspect Err
        end
  	 	{:noreply, state,timeout}
  	 end
     #RECEIVER_END

     #TIMEOUT, PING_REQ
     def handle_info(:timeout,%{socket: socket,timeout: timeout} = state) do
         message = Message.ping_request
         :gen_tcp.send(socket,Packet.encode(message))
         {:noreply,state,timeout}
     end

  	 #DISCONNECT, #END_OF_PROCESS
  	 def handle_info({:tcp_closed, socket}, %{socket: socket} = state) do
          {:stop,"TCP connection closed.", state}
  	 end

     #END_OF_PROCESS
     def terminate(reason,state) do
       state.module.disconnect(reason)
      :ok
     end

    #GEN_SERVER : END 
     defp get_timeout(keep_alive) do
            if keep_alive == 0 do
                :infinity
            else
                (keep_alive*1000) - 5; # we will send pingreq before 5 sec of timeout.
            end
     end
end