# frozen_string_literal: true

source 'https://rubygems.org'

group :preload do
	gem 'utopia', '~> 2.19.2'
	gem 'utopia-gallery'
	gem 'utopia-analytics'

	gem 'relaxo-model', '~> 0.10.0'

	gem 'trenni-sanitize'
	gem 'markly'
	gem 'bcrypt'

	gem 'variant'
end

gem 'bake'
gem 'bundler'
gem 'rack-test'
gem 'net-smtp'

group :development do
	gem 'guard-falcon', require: false
	gem 'guard-rspec', require: false
	
	gem 'rspec'
	gem 'covered'
	
	gem 'async-rspec'
	gem 'benchmark-http'
end

group :production do
	gem 'falcon'
end
