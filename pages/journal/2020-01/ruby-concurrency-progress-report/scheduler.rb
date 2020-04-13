class Scheduler
	# Wait for the given file descriptor to become readable.
	def wait_readable(fd)
	end
	
	# Wait for the given file descriptor to become writable.
	def wait_writable(fd)
	end
	
	# Wait for the given file descriptor to match the specified events within the specified timeout.
	def wait_for_single_fd(fd, events, timeout)
	end
	
	# Sleep the current task for the specified duration, or forever if not specified.
	def wait_sleep(duration = nil)
	end
	
	# The Ruby virtual machine is going to enter a system level blocking operation.
	def enter_blocking_region
	end
	
	# The Ruby virtual machine has completed the system level blocking operation.
	def exit_blocking_region
	end
	
	# Intercept the creation of a non-blocking fiber.
	def fiber(&block)
		Fiber.new(blocking: false, &block)
	end
	
	# Invoked when the thread exits.
	def run
		# Implement event loop here.
	end
end
