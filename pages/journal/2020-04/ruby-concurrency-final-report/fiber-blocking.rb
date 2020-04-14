Fiber.new(blocking: false) do
	puts Fiber.current.blocking? # false
	
	# May invoke `Thread.scheduler&.wait_readable`.
	io.read(...)
	
	# May invoke `Thread.scheduler&.wait_writable`.
	io.write(...)
	
	# Will invoke `Thread.scheduler&.wait_sleep`.
	sleep(n)
end.resume