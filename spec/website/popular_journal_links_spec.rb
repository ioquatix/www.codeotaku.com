
require_relative '../website_context'

# Learn about best practice specs from http://betterspecs.org
RSpec.describe "popular journal links" do
	include_context "website"
	
	include_examples "valid page", "/journal/2018-06/asynchronous-ruby/index"
	include_examples "valid page", "/journal/2018-06/improving-ruby-concurrency/index"
	include_examples "valid page", "/journal/2018-11/fibers-are-the-right-solution/index"
	include_examples "valid page", "/journal/2019-02/falcon-early-hints/index"
	include_examples "valid page", "/journal/2018-10/http-2-for-ruby-web-development/index"
end
