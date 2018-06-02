
# Creates a reactor and runs a task.
Async::Reactor.run do |task|
	# Tasks can be nested:
	task.async do |nested_task|
		nested_task.sleep(5)
	end
	
	task.sleep(5)
end
