defmodule Bus.IdProvider do
	use GenServer
	require Logger 

	def get_id do
		GenServer.call(__MODULE__,:get)
	end

	def free_id(id) do
		GenServer.call(__MODULE__,{:delete,id})
	end

	def start_link do
	    GenServer.start_link(__MODULE__,Map.new(),[name: __MODULE__])
	end

	def init(state) do
	  	IO.inspect "Id Provider online." 
	  	{:ok}
  	end

  	def handle_call(:get,_From,state) do
  		Id = Enum.find(state, 1 , fn(x) -> x == nil end)
  		new_state =  Map.put(state,Id,true)
  		{:reply,Id,new_state}
  	end

  	def handle_call({:delete,id},_From,state) do
  		new_state = Map.delete(state, id)
  		{:reply,:done,new_state}
  	end

end