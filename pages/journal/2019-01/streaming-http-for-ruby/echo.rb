#!/usr/bin/env ruby

require 'async'
require 'async/http/url_endpoint'
require 'async/http/server'
require 'async/http/client'

# Show what's going on under the hood:
# Async.logger.debug!

Async do
	endpoint = Async::HTTP::URLEndpoint.parse("http://localhost:8080", timeout: 5)
	
	# Run the server in a separate fiber:
	server_task = Async do
		server = Async::HTTP::Server.for(endpoint) do |request|
			# Receive the request:
			Async::HTTP::Response[200,
				{'content-type' => 'text/plain'},
				# We echo the body back to the client:
				request.body
			]
		end
		
		server.run
	end
	
	# Create a client:
	client = Async::HTTP::Client.new(endpoint)
	
	# Make the request (it gets wrapped into Async::HTTP::Request):
	body = Async::HTTP::Body::Writable.new
	
	response = client.post("/", {}, body)
	
	5.times do
		body.write(`fortune`)
		puts "*~" * 40
		puts response.body.read
	end
	
	body.close
	response.finish
ensure
	# Stop the server:
	server_task.stop if server_task
	
	# Close any persistent connections:
	client.close if client
end
