#!/usr/bin/env rackup

require_relative 'config/environment'

require 'utopia/tags/gallery'
require 'utopia/tags/google-analytics'

if RACK_ENV == :production
	# Handle exceptions in production with a error page and send an email notification:
	use Utopia::Exceptions::Handler
	use Utopia::Exceptions::Mailer
else
	# We want to propate exceptions up when running tests:
	use Rack::ShowExceptions unless RACK_ENV == :test
	
	# Serve the public directory in a similar way to the web server:
	use Utopia::Static, root: 'public'
end

use Rack::Sendfile

use Utopia::ContentLength

use Utopia::Redirection::Rewrite,
	'/' => '/index'

use Utopia::Redirection::Moved, "/samuel-williams", "/about"
use Utopia::Redirection::Moved, "/blog", "/journal"
use Utopia::Redirection::Moved, "/game-mechanics-society", "http://www.gmsoc.org"

use Utopia::Redirection::DirectoryIndex

use Utopia::Redirection::Errors,
	404 => '/errors/file-not-found'

use Utopia::Localization,
	:default_locale => 'en',
	:locales => ['en', 'ja', 'zh'],
	:nonlocalized => ['/_static/', '/_cache/']

use Utopia::Controller,
	cache_controllers: (RACK_ENV == :production),
	base: Utopia::Controller::Base

use Utopia::Static

# Serve dynamic content
use Utopia::Content,
	cache_templates: (RACK_ENV == :production),
	tags: {
		'deferred' => Utopia::Tags::Deferred,
		'override' => Utopia::Tags::Override,
		'node' => Utopia::Tags::Node,
		'environment' => Utopia::Tags::Environment.for(RACK_ENV),
		'gallery' => Utopia::Tags::Gallery,
		'google-analytics' => Utopia::Tags::GoogleAnalytics,
	}

run lambda { |env| [404, {}, []] }
