#!/usr/bin/env RUBY_VERSION=ruby-thread-scheduler

TOPICS = ["nonblocking", "ruby", "is", "so", "great"]
def fetch(urls)
	urls.each do |url|
		response = Net::HTTP.get(url)
	end
end