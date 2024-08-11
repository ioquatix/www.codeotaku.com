def process_response!(response)
	if response.tc != 0
		# We hardcode this behaviour for now.
		try_next_server!
	else
		succeed response
	end
end
