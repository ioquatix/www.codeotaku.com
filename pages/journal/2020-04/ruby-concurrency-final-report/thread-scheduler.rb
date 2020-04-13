scheduler = Scheduler.new # implementation defined
Thread.current.scheduler = scheduler

Fiber do
	# Equivalent to:
	# 	Thread.scheduler&.wait_readable(io.filedes)
	io.wait_readable
end