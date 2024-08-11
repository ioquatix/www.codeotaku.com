def try_next_server!
	if @request
		@request.close_connection
		@request = nil
	end
				
	if @servers.size > 0
		@server = @servers.shift

		# We make requests one at a time to the given server, naturally the servers
		# are ordered in terms of priority.
		case @server[0]
		when :udp
			@request = UDPRequestHandler.open(@server[1], @server[2], self)
		when :tcp
			@request = TCPRequestHandler.open(@server[1], @server[2], self)
		else
			raise InvalidProtocolError.new(@server)
		end
					
		# Setting up the timeout...
		EventMachine::Timer.new(@timeout) do
			try_next_server!
		end
	else
		# Signal that the deferrable has failed and resolution was not possible:
		fail ResolutionFailure.new("No available servers responded to the request.")
	end
end
