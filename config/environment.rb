# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2016-2022, by Samuel Williams.

require 'bundler/setup'
Bundler.setup

require 'utopia/setup'
UTOPIA ||= Utopia.setup

require_relative '../db/environment'

require 'utopia/extensions/array_split'
require 'json'

require 'live'
require 'live/developer_view'
require 'live/clock_view'

require 'async/websocket/adapters/rack'

require 'traces'
require 'metrics'
