defmodule Bus.Mqtt do
	 use GenServer
	 require Logger 

	 alias Bus.Message
	 alias Bus.Protocol.Packet

	  def start_link do
	    GenServer.start_link(__MODULE__,[],[name: __MODULE__])
	  end


	  defp connect() do
	  	host = 'localhost'
	  	port = 1883
	  	opts = [:binary, active: :once]
	    case :gen_tcp.connect(host, port, opts) do
	    	{:ok, socket} ->
	    		{:ok,socket}
	    	_ 			  -> {:error,"Error"}
	    end
	  end

	  def disconnect() do
	  	
	  end

	  def publish() do
	  end

	  def subscribe() do
	  	
	  end

	  def unsubscribe() do
	  	
	  end

	  def pingreq() do
	  	
	  end

	  # connect to mqtt,
	  # take params from config.
	  def init([]) do

    	case connect() do
    		{:ok,socket} ->
    			IO.inspect "TCP connected."
    			
    			opts = [client_id: "123", username: "VJ", password: "asdf", will_topic: "",will_message: "", will_qos: 1,will_retain: 0,clean_session: 1, keep_alive: 100]
    		
    			client_id     = opts |> Keyword.fetch!(:client_id)
		        username      = opts |> Keyword.get(:username, "")
		        password      = opts |> Keyword.get(:password, "")
		        will_topic    = opts |> Keyword.get(:will_topic, "")
		        will_message  = opts |> Keyword.get(:will_message, "")
		        will_qos      = opts |> Keyword.get(:will_qos, 0)
		        will_retain   = opts |> Keyword.get(:will_retain, 0)
		        clean_session = opts |> Keyword.get(:clean_session, 1)
		        keep_alive    = opts |> Keyword.get(:keep_alive, 100)

		        message = Message.connect(client_id, username, password,
		                                  will_topic, will_message, will_qos,
		                                  will_retain, clean_session, keep_alive)
		        packet = Packet.encode(message)
		        IO.inspect packet
		        :gen_tcp.send(socket,packet)
    			{:ok, %{socket: socket}}
    		
    		{:error,Error}->
    			IO.inspect "Error while connecting TCP."
    			{:error,Error}
    	end
  	  end

  	 #all the messages will go from gere.
  	 #process , encode and then only call this one.
  	 # def handle_cast({:send_packet,data},%{socket: socket} = state) do
  	 # 	:gen_tcp.send(socket,data)
  	 # 	IO.inspect "Packet Sent."
  	 # 	{:noreply,state}
  	 # end

  	 def handle_call({:connect,opts},%{socket: socket} = state) do

  	 	# host          = opts |> Keyword.fetch!(:host)
        # port          = opts |> Keyword.fetch!(:port)

        client_id     = opts |> Keyword.fetch!(:client_id)
        username      = opts |> Keyword.get(:username, "")
        password      = opts |> Keyword.get(:password, "")
        will_topic    = opts |> Keyword.get(:will_topic, "")
        will_message  = opts |> Keyword.get(:will_message, "")
        will_qos      = opts |> Keyword.get(:will_qos, 0)
        will_retain   = opts |> Keyword.get(:will_retain, 0)
        clean_session = opts |> Keyword.get(:clean_session, 1)
        keep_alive    = opts |> Keyword.get(:keep_alive, 100)

        message = Message.connect(client_id, username, password,
                                  will_topic, will_message, will_qos,
                                  will_retain, clean_session, keep_alive)
        :gen_tcp.send(socket,message)
        {:reply , "cool" , state}
  	 end


  	 #all the messages will from tcp will be received here.
  	 #this will be the entry point of all the tcp messages,
  	 #get message from here, decode it and process it.
  	 def handle_info({:tcp, socket, msg}, %{socket: socket} = state) do
  	 	IO.inspect "Packet Arrived."
  	 	IO.inspect msg
  	 	
  	 	:inet.setopts(socket, active: :once)
  	 	{:noreply, state}
  	 end

  	 def handle_info({:tcp_closed, socket}, %{socket: socket} = state) do
  	 	IO.inspect "TCP closed."
  	 	{:noreply, state}
  	 end

  	 def terminate(reason,state) do
  	 	:ok
  	 end

  	 def code_change(_old_ver,state,_extra) do
  	 	{:ok, state}
  	 end

end