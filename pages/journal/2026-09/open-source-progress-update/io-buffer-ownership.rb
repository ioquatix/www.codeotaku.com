source = +"Hello World"
root = IO::Buffer.for(source)
slice = root.slice(0, 5)

root.locked do
	slice.locked do
		# Both locks retain the same root allocation.
	end

	root.locked? # => true; the outer user still holds its lock.
end

root.free

slice.valid? # => false
slice.get_string # Raises IO::Buffer::InvalidatedError.
