#!/usr/bin/env -S falcon host
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2022, by Samuel Williams.

hostname = File.basename(__dir__)

service hostname do
	include Falcon::Environment::Rack
	include Falcon::Environment::LetsEncryptTLS
end
