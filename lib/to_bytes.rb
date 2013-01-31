
def bytes_to_string(size)
	human_size = size
	levels = 0
	while human_size > 1024
		human_size /= 1024.0
		levels += 1
	end

	return sprintf("%0.#{levels}f%s", human_size, ['', 'K', 'M', 'G', 'T', 'X'].fetch(levels)) + 'Bytes'
end

class Fixnum
	def to_bytes
		return bytes_to_string(self)
	end
end
