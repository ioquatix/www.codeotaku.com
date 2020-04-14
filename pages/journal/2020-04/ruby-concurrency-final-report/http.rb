def fetch_topics(topics)
	counts = {}
	
	conditions = topics.map do |topic|
		condition = Scheduler::Condition.new
		
		Fiber.new(blocking: Fiber.current.blocking?) do
			uri = URI("https://www.google.com/search?q=#{topic}")
			counts[topic] = Net::HTTP.get(uri).scan(topic).size
			
			condition.signal
		end.resume
		
		condition
	end
	
	# Wait for all requests to finish:
	conditions.each(&:wait)
	
	return counts
end