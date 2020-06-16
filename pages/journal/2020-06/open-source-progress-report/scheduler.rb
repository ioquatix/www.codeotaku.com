Async do
	barrier = Async::Barrier.new
	
	3.times do
		barrier.async do
			# These requests will happen concurrently:
			Net::HTTP.get(URI "https://www.codeotaku.com/index")
		end
	end
	
	# Wait for all the requests to finish:
	barrier.wait
end