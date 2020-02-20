# frozen_string_literal: true

require 'bundler/setup'
Bundler.setup

require 'utopia/setup'
UTOPIA = Utopia.setup

require 'utopia/extensions/array_split'
require 'json'

require_relative '../db/environment'

if UTOPIA.production?
	require 'scout_apm'
	ScoutApm::Rack.install!
end
