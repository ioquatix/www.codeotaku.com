
require 'async/rspec/reactor'
require 'async'

require 'falcon/server'
require 'benchmark/http/spider'

require_relative 'website_context'

RSpec.describe "website", timeout: 120 do
	include_context "website"
	include_context Async::RSpec::Reactor
	
	it "should be responsive" do
		endpoint = Async::HTTP::Endpoint.parse("http://localhost:8282")
		
		server_task = Async do
			middleware = Falcon::Server.middleware(app)
			
			server = Falcon::Server.new(middleware, endpoint)
			
			server.run
		end
		
		spider = Benchmark::HTTP::Spider.new(depth: 10)
		
		statistics = spider.call(["http://localhost:8282"]) do |method, uri, response|
			if response.failure?
				Async.logger.error{"#{method} #{uri} -> #{response.status}"}
			end
		end
		
		statistics.print
		
		expect(statistics.failed).to be_zero
	end
end
