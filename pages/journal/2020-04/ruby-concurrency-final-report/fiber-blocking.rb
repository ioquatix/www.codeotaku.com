# The default:
Fiber.new(blocking: true) do
	puts Fiber.current.blocking? # true
end.resume

Fiber.new(blocking: false) do
	puts Fiber.current.blocking? # false
end.resume