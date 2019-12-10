# Channels for communication between isolates:
channel = Isolate::Channel.new

# @option bare [Boolean] minimal stdlib (e.g. exclude Thread, etc).
Isolate.new(bare: true) do |isolate|
	undef Thread # or maybe something like this?
	
	isolate.signal(:int) do
		
	end
	
	Async do |task|
		isolate.selector = task.reactor
		
		# fiber-based concurrency for all I/O operations:
		object = channel.read
	end
end

Isolate.new do
	# Default to blocking I/O:
	channel.write({foo: "bar"})
end

Isolate.wait_all