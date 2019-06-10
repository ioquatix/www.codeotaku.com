
source "https://rubygems.org"

gem "utopia", "~> 2.8.0"
gem "utopia-gallery", "~> 2.0"
gem "utopia-analytics"

gem "rake"
gem "bundler"

gem "rack-freeze", "~> 1.2"

gem "relaxo-model", "~> 0.10.0"

gem "trenni-sanitize"
gem "kramdown"
gem "kramdown-parser-gfm"
gem "bcrypt"

group :development do
	# For `rake server`:
	gem "async-http"
	
	gem "guard-falcon", require: false
	gem 'guard-rspec', require: false
	
	# For `rake console`:
	gem "pry"
	gem "rack-test"
	
	# For `rspec` testing:
	gem "rspec"
	gem "covered"
end

group :production do
	gem "scout_apm", "~> 2.4.0"
end
