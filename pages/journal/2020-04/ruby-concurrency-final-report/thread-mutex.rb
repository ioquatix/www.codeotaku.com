mutex = Mutex.new

puts Thread.current.blocking? # 1 (true)

Fiber.new(blocking: false) do
	puts Thread.current.blocking? # false
	
	mutex.synchronize do
		puts Thread.current.blocking? # (1) true
	end
	
	puts Thread.current.blocking? # false
end.resume