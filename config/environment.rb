
require 'bundler/setup'
Bundler.setup

require 'utopia/setup'
Utopia.setup

require 'utopia/extensions/array'

RACK_ENV = ENV.fetch('RACK_ENV', :development).to_sym unless defined? RACK_ENV
