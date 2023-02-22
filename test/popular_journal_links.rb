# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2016-2023, by Samuel Williams.

require 'website'

describe "popular journal links" do
	include_context AWebsite
	
	it_behaves_like AValidPage, "/journal/2018-06/asynchronous-ruby/index"
	it_behaves_like AValidPage, "/journal/2018-06/improving-ruby-concurrency/index"
	it_behaves_like AValidPage, "/journal/2018-11/fibers-are-the-right-solution/index"
	it_behaves_like AValidPage, "/journal/2019-02/falcon-early-hints/index"
	it_behaves_like AValidPage, "/journal/2018-10/http-2-for-ruby-web-development/index"
end
