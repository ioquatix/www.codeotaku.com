# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2012-2023, by Samuel Williams.

source 'https://rubygems.org'

group :preload do
	gem 'utopia', '~> 2.22'
	gem 'utopia-gallery'
	gem 'utopia-analytics'
	
	gem 'relaxo-model', '~> 0.19'
	
	gem 'async-websocket'
	
	gem 'xrb-sanitize'
	gem 'markly'
	gem 'bcrypt'

	gem 'variant'
	gem 'live'
	
	gem 'traces-backend-datadog'
	gem 'metrics-backend-datadog'
end

gem 'net-smtp'

group :development do
	gem 'bake-test'
	gem 'rack-test'
	
	gem 'sus'
	gem 'sus-fixtures-async-http'
	
	gem 'covered'
	
	gem 'benchmark-http'
	gem 'io-watch'
end

group :production do
	gem 'falcon'
end
