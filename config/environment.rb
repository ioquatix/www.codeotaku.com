# frozen_string_literal: true

require 'bundler/setup'
Bundler.setup

require 'utopia/setup'
UTOPIA ||= Utopia.setup

require_relative '../db/environment'

require 'utopia/extensions/array_split'
require 'json'

if UTOPIA.production?
	require 'scout_apm'
	ScoutApm::Rack.install!
end
