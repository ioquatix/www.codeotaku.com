
source "https://rubygems.org"

gem "utopia", "~> 2.0.0"
gem "utopia-gallery", "~> 2.0"
gem "utopia-tags-google-analytics"

gem "rake"
gem "bundler"

gem "rack-freeze", "~> 1.2"

gem "datamapper"
gem "dm-sqlite-adapter"

gem "promise"

gem "sanitize"
gem "kramdown"

group :development do
	# For `rake server`:
	gem "puma"
	gem "guard-puma", require: false
	gem 'guard-rspec', require: false
	
	# For `rake console`:
	gem "pry"
	gem "rack-test"
	
	# For `rspec` testing:
	gem "rspec"
	gem "simplecov"
end

group :production do
	# Used for passenger-config to restart server after deployment:
	gem "passenger"
end
