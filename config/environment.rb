# frozen_string_literal: true

require 'bundler/setup'
Bundler.setup

require 'utopia/setup'
Utopia.setup

require 'utopia/extensions/array_split'
require 'json'

RACK_ENV = ENV.fetch('RACK_ENV', :development).to_sym unless defined? RACK_ENV

require_relative '../db/environment'

require 'scout_apm'
ScoutApm::Rack.install!
