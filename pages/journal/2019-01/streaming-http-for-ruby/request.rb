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
			
			Async do
				request.each do |chunk|
					body.write chunk.upcase
				end
				
			ensure
				body.close
			end
			
			# Receive the request:
			Async::HTTP::Response[200,
				{'content-type' => request.headers['content-type']},
				# We echo the body back to the client:
				body
			]
		end
		
		server.run
	end
	
	# Create a client:
	client = Async::HTTP::Client.new(endpoint)
	
	# Make the request (it gets wrapped into Async::HTTP::Request):
	body = Async::HTTP::Body::Writable.new
	
	response = client.post("/", {'content-type' => 'text/plain'}, body)
	
	5.times do
		body.write("ping")
		puts response.body.read.inspect
	end
	
	body.close
	response.finish
ensure
	# Stop the server:
	server_task.stop if server_task
	
	# Close any persistent connections:
	client.close if client
end
