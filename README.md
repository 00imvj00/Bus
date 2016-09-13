## Quick Start

If [available in Hex](https://hex.pm/packages/bus), the package can be installed as:

  1. Add `bus` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:bus, "~> 0.1.4"}]
    end
    ```

  2. Ensure `bus` is started before your application:

    ```elixir
    def application do
      [applications: [:bus]]
    end
    ```
  3. Add Configuration Details in `config.ex` file.
    
    ```elixir
    config :bus, 
     		host: 'localhost',
     		port: 1883,
     		client_id: "1", #needs to be string.
     		keep_alive: 100, #this is in seconds.
     		username: "",
     		password: "",
     		auto_reconnect: true, #if client get disconnected, it will auto reconnect.
     		auto_connect: true, #this will make sure when you start :bus process, it gets connected autometically
     		callback: Bus.Callback #callback module, you need to implement callback inside.
    ```
  4. Publish 
 
     ```elixir
        topic = "a"
        message = "Hello World...!"
        qos = 1
        callback_fun = fn(message) -> IO.puts message end #This function will be called
        when this perticular message will be published.
        Bus.Mqtt.publish(topic,message,callback_fun,qos)
    ```
  5. Subscribe
  
     ```elixir
        topics = ["a","b","c"] #list of topics
        qoses = [1,0,2] #list of qos in same order as topics.
        callback_fun = fn(message) -> IO.puts message end #This function will be called
        when this perticular topic will be subscribed.
        Bus.Mqtt.subscribe(topics,qoses,callback_fun)
    ```
  6. Callback
    
    ```elixir
        defmodule Bus.Callback do
		
		#removed, no longer supported.
          	#def on_publish(data) do
          	#	IO.inspect data
          	#end
          
          	def on_connect(data) do
          		IO.inspect data
          	end
          	
          	def on_disconnect(data) do
          		IO.inspect data
          	end
          
          	def on_error(data) do
          		IO.inspect data
          	end
          	
          	def on_info(data) do
          		IO.inspect data
          	end
          	
          	#removed, no longer supported.
          	#def on_subscribe(data) do
          	#	IO.inspect data
          	#end
          
          	#removed, no longer supported.
          	#def on_unsubscribe(data) do
          	#	IO.inspect data
          	#end
          
          	def on_message_received(topic,message) do
          		IO.inspect topic
          		IO.inspect message
          	end
        
        end
    ```
    This still needs more improvements, may change in upcoming versions.
    
=======
Pure Mqtt client written in Elixir

## Note
    Detailed Documentation is coming soon. 
