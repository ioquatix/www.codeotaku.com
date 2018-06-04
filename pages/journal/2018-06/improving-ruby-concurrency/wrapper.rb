
class Wrapper
	# ... initialze, write, close, etc
	
	def read(*args)
		while result = @io.read_nonblock(*args, exception: false)
			case result
			when :wait_readable
				@selector.wait_readable(@io)
			else
				return result
			end
		end
	end
end

class Selector
	# initialze, wait_writable, etc
	
	def wait_readable(io)
		@readable[io] = Fiber.current
		
		Fiber.yield
		
		@readable.delete(io)
		
		return true
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
end
