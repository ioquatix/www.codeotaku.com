# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require "datadog"

require "open3"
require "console/event/failure"

def git_version(path = "/usr/bin/git")
	stdout, status = Open3.capture2(path, "describe", "--always")
	
	if status.success?
		yield stdout.strip
	end
rescue => error
	Console::Event::Failure.for(error).emit(self)
end

Datadog.configure do |config|
	config.logger.level = Logger::WARN
	
	config.service = 'utopia'
	
	git_version do |version|
		config.version = version
	end
end
