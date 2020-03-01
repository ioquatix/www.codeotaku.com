#!/usr/bin/env rackup
# frozen_string_literal: true

require_relative 'config/environment'

require 'utopia/session'
require 'utopia/gallery'
require 'utopia/analytics'

self.freeze_app

self.warmup do |app|
	# require 'memory_profiler'
	# 
	# MemoryProfiler.start
	# 
	# Signal.trap(:USR2) do
	# 	report = MemoryProfiler.stop
	# 	report.pretty_print
	# end
	# 
	client = Rack::MockRequest.new(app)
	
	client.get('/index')
	client.get('/journal/index')
end

if UTOPIA.production?
	require_relative 'lib/scout'
	use ScoutApm::Instruments::RackRequest
end

if UTOPIA.production?
	# Handle exceptions in production with a error page and send an email notification:
	use Utopia::Exceptions::Handler
	use Utopia::Exceptions::Mailer
else
	# We want to propate exceptions up when running tests:
	use Rack::ShowExceptions unless UTOPIA.testing?
end

use Utopia::Static, root: 'public'

use Utopia::Redirection::Rewrite, {
	'/' => '/index'
}

use Utopia::Redirection::Moved, "/samuel-williams", "/about"
use Utopia::Redirection::Moved, "/blog", "/journal"
use Utopia::Redirection::Moved, "/game-mechanics-society", "http://www.gmsoc.org"

use Utopia::Redirection::Moved, "/projects/jquery-syntax", "https://www.github.com/ioquatix/jquery-syntax", flatten: true
use Utopia::Redirection::Moved, "/journal/2019-11/open-source-update", "/journal/2019-11/open-source-progress-report"

# Old localization redirects:
use Utopia::Redirection::Moved, "/projects/rubydns/index.en", "/en/projects/rubydns/index"

use Utopia::Redirection::DirectoryIndex

use Utopia::Redirection::Errors, {
	404 => '/errors/file-not-found'
}

require 'utopia/localization'
use Utopia::Localization,
	default_locale: 'en',
	locales: ['en', 'ja', 'zh']

require 'utopia/session'
use Utopia::Session,
	expires_after: 3600 * 24,
	secret: UTOPIA.secret_for(:session),
	secure: true

use Utopia::Controller

use Utopia::Static

# Serve dynamic content
use Utopia::Content,
	namespaces: {
		"analytics" => Utopia::Analytics,
		"gallery" => Utopia::Gallery::Tags.new,
	}

run lambda { |env| [404, {}, []] }
