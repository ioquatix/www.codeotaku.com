# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require "open3"

def git_version(path = "/usr/bin/git")
	stdout, status = Open3.capture2(path, "describe", "--always")
	
	if status.success?
		yield stdout.strip
	end
rescue => error
	Console.warn(self, "Unable to determine git version!", error)
	
	return nil
end

def prepare_datadog!
	require "datadog"
	
	Datadog.configure do |config|
		config.logger.level = Logger::WARN
		
		config.service = 'utopia'
		
		git_version do |version|
			config.version = version
		end
	end
rescue => error
	Console.warn(self, "Unable to configure Datadog!", error)
end

def prepare
	prepare_datadog!
	
	require "traces/provider/async"
	require "traces/provider/protocol/http2"
end
