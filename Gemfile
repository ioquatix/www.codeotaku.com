
source 'https://rubygems.org'

group :preload do
	gem 'utopia', '~> 2.11'
	gem 'utopia-gallery', '~> 2.3'
	gem 'utopia-analytics'

	gem 'rake'
	gem 'bundler'

	gem 'rack-freeze', '~> 1.2'

	gem 'relaxo-model', '~> 0.10.0'

	gem 'trenni-sanitize'
	gem 'kramdown'
	gem 'kramdown-parser-gfm'
	gem 'bcrypt'
end

gem 'scout_apm'

group :development do
	# For `rake server`:
	gem 'guard-falcon', require: false
	gem 'guard-rspec', require: false
	
	# For `rake console`:
	gem 'pry'
	gem 'rack-test'
	
	# For `rspec` testing:
	gem 'rspec'
	gem 'covered'
	
	gem 'async-rspec'
	gem 'benchmark-http'
end
