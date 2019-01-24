#!/usr/bin/env ruby

require 'async'
require 'async/http/url_endpoint'
require 'async/http/server'
require 'async/http/client'

Async do
	endpoint = Async::HTTP::URLEndpoint.parse("http://localhost:8080")
	
	# Run the server in a separate fiber:
	server_task = Async do
		server = Async::HTTP::Server.for(endpoint) do |request|
			# Receive the request:
			Async::HTTP::Response[200,
				{'content-type' => 'text/plain'},
				["Hello World!"]
			]
		end
		
		server.run
	end
	
	# Create a client:
	client = Async::HTTP::Client.new(endpoint)
	
	# Make the request (it gets wrapped into Async::HTTP::Request):
	response = client.get("/")
	
	# Print out the response:
	puts "Status: #{response.status} (#{response.success?})"
	puts "Headers: #{response.headers.to_h}"
	puts "Body: #{response.read.inspect}"
ensure
	# Stop the server:
	server_task.stop if server_task
	
	# Close any persistent connections:
	client.close if client
end
