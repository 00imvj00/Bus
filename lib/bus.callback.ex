defmodule Bus.Callback do
	
	def on_publish(data) do
		IO.inspect data
	end

	def on_connect(data) do
		IO.inspect data
	end

	def on_subscribe(data) do
		IO.inspect data
	end

	def on_unsubscribe(data) do
		IO.inspect data
	end

end