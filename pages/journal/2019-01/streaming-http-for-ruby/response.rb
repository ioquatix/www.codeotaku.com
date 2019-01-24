#!/usr/bin/env ruby

require 'async'
require 'async/http/url_endpoint'
require 'async/http/server'
require 'async/http/client'

# Show what's going on under the hood:
# Async.logger.debug!

require 'json'
APPLICATION_JSON_STREAM = "application/json; boundary=NL".freeze

Async do
	endpoint = Async::HTTP::URLEndpoint.parse("http://localhost:8080", timeout: 5)
	
	# Run the server in a separate fiber:
	server_task = Async do
		server = Async::HTTP::Server.for(endpoint) do |request|
			body = Async::HTTP::Body::Writable.new
			
			Async do |task|
				while true
					duration = rand
					task.sleep duration
					body.write(JSON.dump(["Hello World!", "I slept for #{duration}"]) + "\n")
				end
			end
			
			# Receive the request and respond with the dynamic body:
			Async::HTTP::Response[200,
				{'content-type' => APPLICATION_JSON_STREAM},
				# We echo the body back to the client:
				body
			]
		end
		
		server.run
	end
	
	# Create a client:
	client = Async::HTTP::Client.new(endpoint)
	
	response = client.get("/")
	
	response.each do |chunk|
		# As the server generates chunks we will receive them.
		# While Async::HTTP guarantees to preserve the chunk boundaries with HTTP/1.1 and HTTP/2, you might prefer to do additional buffering here to improve robustness.
		puts JSON.parse(chunk).inspect
	end
ensure
	# Stop the server:
	server_task.stop if server_task
	
	# Close any persistent connections:
	client.close if client
end
