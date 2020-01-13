class Scheduler
	def fiber(*arguments, **options, &block)
		Fiber.new(&block).resume
	end
end

Fiber do
	# Non-blocking user code.
end