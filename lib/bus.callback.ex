defmodule Bus.Callback do
	
	def on_publish(data) do
		IO.inspect data
	end

	def on_connect(data) do
		IO.inspect data
	end

	def on_disconnect(data) do
		IO.inspect data
	end

	def on_error(data) do
		
	end
	
	def on_subscribe(data) do
		IO.inspect data
	end

	def on_unsubscribe(data) do
		IO.inspect data
	end

	def on_message_received(topic,message) do
		IO.inspect topic
		IO.inspect message
	end


end