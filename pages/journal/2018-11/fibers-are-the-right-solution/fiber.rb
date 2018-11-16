#!/usr/bin/env ruby

require 'socket'
require 'fiber'
require 'io/nonblock'

# The full implementation is given here, in order to show all the parts. A simpler implementation is given below.
class Reactor
	def initialize
		@readable = {}
		@writable = {}
	end
	
	def run
		while @readable.any? or @writable.any?
			readable, writable = IO.select(@readable.keys, @writable.keys, [])
			
			readable.each do |io|
				@readable[io].resume
			end
			
			writable.each do |io|
				@writable[io].resume
			end
		end
	end
	
	def wait_readable(io)
		@readable[io] = Fiber.current
		Fiber.yield
		@readable.delete(io)
		
		return yield if block_given?
	end
	
	def wait_writable(io)
		@writable[io] = Fiber.current
		Fiber.yield
		@writable.delete(io)
		
		return yield if block_given?
	end
end

server = TCPServer.new('localhost', 9090)
reactor = Reactor.new

server.nonblock = true

Fiber.new do
	loop do
		client = reactor.wait_readable(server) {server.accept}
		
		Fiber.new do
			client.nonblock = true
			
			while buffer = reactor.wait_readable(client) {client.gets}
				reactor.wait_writable(client)
				client.puts(buffer)
			end
			
			client.close
		end.resume
	end
end.resume

reactor.run
