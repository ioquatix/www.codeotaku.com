module Async
	class Scheduler
		if Thread.instance_methods.include?(:scheduler)
			def self.supported?
				true
			end
		else
			def self.supported?
				false
			end
		end
		
		def initialize(reactor)
			@reactor = reactor
			@blocking_started_at = nil
		end
		
		private def from_descriptor(fd)
			io = IO.for_fd(fd, autoclose: false)
			return Wrapper.new(io, @reactor)
		end
		
		# Wait for the given I/O to become readable.
		def wait_readable(fd, timeout = nil)
			wrapper = from_descriptor(fd)
			wrapper.wait_readable(timeout)
		ensure
			wrapper.reactor = nil
		end
		
		# ...