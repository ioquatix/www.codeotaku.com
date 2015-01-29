#!/usr/bin/env rackup

# Setup encodings:
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

# Setup the server environment:
RACK_ENV = ENV.fetch('RACK_ENV', :development).to_sym unless defined?(RACK_ENV)

# Allow loading library code from lib directory:
$LOAD_PATH << File.expand_path("../lib", __FILE__)

require 'utopia'
require 'utopia/extensions/array'
require 'utopia/session/encrypted_cookie'
require 'utopia/tags/gallery'
require 'utopia/tags/google-analytics'
require 'rack/cache'

require 'to_bytes'

if RACK_ENV == :production
	use Utopia::ExceptionHandler, "/errors/exception"
	use Utopia::MailExceptions
else
	use Rack::ShowExceptions
end

use Rack::Sendfile

if RACK_ENV == :production
	use Rack::Cache,
		metastore: "file:#{Utopia::default_root("cache/meta")}",
		entitystore: "file:#{Utopia::default_root("cache/body")}",
		verbose: RACK_ENV == :development
end

use Rack::ContentLength

use Utopia::Redirector,
	patterns: [
		Utopia::Redirector::DIRECTORY_INDEX,
		[:moved, "/samuel-williams", "/about"],
		[:moved, "/blog", "/journal"],
		[:moved, "/game-mechanics-society", "http://www.gmsoc.org"],
	],
	strings: {
		'/' => '/index',
	},
	errors: {
		404 => "/errors/file-not-found"
	}

use Utopia::Session::EncryptedCookie,
	:expire_after => 2592000,
	:secret => '6965ae9b95a55907648721638d70cf1a'
	

use Utopia::Localization,
	:default_locale => 'en',
	:locales => ['en', 'ja', 'zh'],
	:nonlocalized => ['/_static/']

use Utopia::Controller,
	cache_controllers: (RACK_ENV == :production)

use Utopia::Static

use Utopia::Content,
	cache_templates: (RACK_ENV == :production),
	tags: {
		'deferred' => Utopia::Tags::Deferred,
		'override' => Utopia::Tags::Override,
		'node' => Utopia::Tags::Node,
		'environment' => Utopia::Tags::Environment.for(RACK_ENV),
		'gallery' => Utopia::Tags::Gallery
	}

run lambda { |env| [404, {}, []] }
