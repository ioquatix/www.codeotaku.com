count = 0

5.times do
	Async do
		# Save the value of count:
		tmp = count
		
		# Perform some non-deterministic operation:
		internet.get(reference)
		
		# Increment the value of count:
		count = tmp + 1
	end
end

# What is the value of count? 5?
puts count
