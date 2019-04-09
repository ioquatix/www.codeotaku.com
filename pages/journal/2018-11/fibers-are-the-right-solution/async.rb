#!/usr/bin/env ruby

require 'async'
require 'async/io/tcp_socket'

Async do |task|
	server = Async::IO::TCPServer.new('localhost', 9090)
	
	loop do
		client, address = server.accept
		
		task.async do
			while buffer = client.gets
				client.puts(buffer)
			end
			
			client.close
		end
	end
end
