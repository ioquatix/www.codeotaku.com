puts Thread.current.blocking? # 1 (true)

Fiber.new(blocking: false) do
	puts Thread.current.blocking? # false
end.resume