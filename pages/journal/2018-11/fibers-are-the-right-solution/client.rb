#!/usr/bin/env ruby

require 'async'
require 'async/io/tcp_socket'

Async do |task|
	client = Async::IO::TCPSocket.new('localhost', 9090)
	
	client.puts "Hello World"
	$stdout.puts client.gets
	
	client.close
end
