
source "https://rubygems.org"

gem "utopia", "~> 1.9.3"
gem "utopia-tags-gallery"
gem "utopia-tags-google-analytics"

gem "datamapper"
gem "dm-sqlite-adapter"

gem "promise"

gem "sanitize"
gem "kramdown"


gem "rake"
gem "bundler"

group :development do
	# For `rake server`:
	gem "puma"
	
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
