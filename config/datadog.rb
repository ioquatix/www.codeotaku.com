# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require 'datadog'

Datadog.configure do |config|
	config.service = 'utopia'
	config.version = `git describe --always`.strip
	
	config.logger.level = Logger::WARN
end
