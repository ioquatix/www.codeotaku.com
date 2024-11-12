class MyController
	def streaming_sse
		body = proc do |stream|
			while true
				stream << "data: The time is #{Time.now}\n\n"
				sleep 1
			end
		rescue => error
		ensure
			stream.close(error)
		end
		
		self.response = Rack::Response[200, {"content-type" => "text/event-stream"}, body]
	end
end
