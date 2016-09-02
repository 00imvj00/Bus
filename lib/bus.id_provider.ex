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
	    GenServer.start_link(__MODULE__,Map.new,[name: __MODULE__])
	end

	def init(state) do
	  	{:ok,state}
  	end

  	def handle_call(:get,_From,state) do
  		{:ok,id} = get_id_from_map(state,1)
  		new_state =  Map.put(state,id,true)
  		{:reply,id,new_state}
  	end

  	def handle_call({:delete,id},_From,state) do
  		new_state = Map.delete(state, id)
  		{:reply,:done,new_state}
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