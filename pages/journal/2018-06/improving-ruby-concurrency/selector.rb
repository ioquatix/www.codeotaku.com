# frozen_string_literal: false
require 'test/unit'
require 'io/nonblock'
require 'fiber'

class Selector
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
	
	def wait_readable(fd)
		io = IO.for_fd(fd)
		
		@readable[io] = Fiber.current
		
		Fiber.yield
		
		@readable.delete(io)
		
		return true
	end
	
	def wait_writable(fd)
		io = IO.for_fd(fd)
		
		@writable[io] = Fiber.current
		
		Fiber.yield
		
		@writable.delete(io)
		
		return true
	end
	
	def wait_for_single_fd(fd, events, duration)
		puts "Wait for single fd: #{fd.inspect} #{events.inspect} #{duration.inspect}"
		
		return 0
	end
end

class TestIOSelector < Test::Unit::TestCase
	MESSAGE = "Hello World"
	
	def test_read
		message = nil
		
		thread = Thread.new do
			selector = Selector.new
			Thread.current.selector = selector
			
			i, o = IO.pipe
			i.nonblock = true
			o.nonblock = true
			
			Fiber.new do
				message = i.read(20)
			end.resume
			
			Fiber.new do
				o.write("Hello World")
				o.close
			end.resume
			
			selector.run
		end

		thread.join

		assert_equal(message, MESSAGE)
	end
end