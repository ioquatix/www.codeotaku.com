# frozen_string_literal: true

source 'https://rubygems.org'

group :preload do
	gem 'utopia', '~> 2.18'
	gem 'utopia-gallery'
	gem 'utopia-analytics'

	gem 'relaxo-model', '~> 0.10.0'

	gem 'trenni-sanitize'
	gem 'markly'
	gem 'bcrypt'
end

gem 'bake'
gem 'bundler'

gem 'rack-test'

group :development do
	# For `rake server`:
	gem 'guard-falcon', require: false
	gem 'guard-rspec', require: false
	
	# For `rspec` testing:
	gem 'rspec'
	gem 'covered'
	
	gem 'async-rspec'
	gem 'benchmark-http'
end

group :production do
	gem 'falcon'
end
