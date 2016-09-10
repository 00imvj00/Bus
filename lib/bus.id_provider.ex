defmodule Bus.IdProvider do
	use GenServer
	require Logger 

	#APIs : start

	def start_link do
	    GenServer.start_link(__MODULE__,Map.new,[name: __MODULE__])
	end

	def get_id(cb) do
		GenServer.call(__MODULE__,{:get,cb})
	end

	def free_id(id) do
		{:done,cb} = GenServer.call(__MODULE__,{:delete,id}) #improve error handling.
		cb
	end

	#APSs : end

	def init(state) do
	  	{:ok,state}
  	end

  	def handle_call({:get,cb},_From,state) do
  		{:ok,id} = get_id_from_map(state,1)
  		new_state =  Map.put(state,id,cb)
  		{:reply,id,new_state}
  	end

  	def handle_call({:delete,id},_From,state) do
  		cb = Map.get(state,id)
  		new_state = Map.delete(state, id)
  		{:reply,{:done,cb},new_state}
  	end

  	defp get_id_from_map(map,position) when is_integer(position) do
  		 cond do
  		   position > 65535 ->
  		   		{:error,"Reached at maximum."}
  		   true 			->
  		    	case Map.get(map,position) do
		  		 	nil -> 
		  		 		{:ok,position}
		  		 	val ->
		  		 	   get_id_from_map(map,position + 1)
		  		end 
  		 end
  	end

end