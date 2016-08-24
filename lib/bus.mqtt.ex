defmodule Bus.Mqtt do
	 import GenServer
	 require Logger 

	 alias Bus.Message
	 alias Bus.Protocol.Packet

	  def start_link do
	    GenServer.start_link(__MODULE__,[],[name: __MODULE__])
	  end

	  #store whole these details in state.
	  def connect() do
	  	opts = %{host: 'localhost',
	  			 port: 1883,
	  			 client_id: "123",
	  			  username: "VJ",
	  			   password: "asdf",
	  			    will_topic: "",
	  			    will_message: "",
	  			     will_qos: 1,
	  			     will_retain: 0,
	  			     clean_session: 1,
	  			     keep_alive: 100
	  			}
    	GenServer.call( __MODULE__ , { :connect , opts })
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
	  	IO.inspect "Init." 
	  	{:ok ,%{socket: nil}}
  	  end

  	 def handle_call({ :connect ,opts},_From ,%{socket: skt} = state) do

  	 	host          = opts |> Map.fetch!(:host)
        port          = opts |> Map.fetch!(:port)

        client_id     = opts |> Map.fetch!(:client_id)
        username      = opts |> Map.get(:username, "")
        password      = opts |> Map.get(:password, "")
        will_topic    = opts |> Map.get(:will_topic, "")
        will_message  = opts |> Map.get(:will_message, "")
        will_qos      = opts |> Map.get(:will_qos, 0)
        will_retain   = opts |> Map.get(:will_retain, 0)
        clean_session = opts |> Map.get(:clean_session, 1)
        keep_alive    = opts |> Map.get(:keep_alive, 100)

        message = Packet.encode(Message.connect(client_id, username, password,
                                  will_topic, will_message, will_qos,
                                  will_retain, clean_session, keep_alive))

        tcp_opts = [:binary, active: :once]
	    {:ok, socket} = :gen_tcp.connect(host, port, tcp_opts)
        :gen_tcp.send(socket,message)

        {:reply , %{:sent} , %{socket: socket}}
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

  	 #This will call when tcp will be closed, try to reconnect.
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