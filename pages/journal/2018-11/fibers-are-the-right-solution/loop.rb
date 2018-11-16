#!/usr/bin/env ruby

require 'socket'

server = TCPServer.new('localhost', 9090)

loop do
	client = server.accept
	
	while buffer = client.gets
		client.puts(buffer)
	end
	
	client.close
end
