
require 'scout_apm/rack'

class ScoutApm::Instruments::RackRequest
	def initialize(app)
		@app = app
	end
	
	def call(env)
		ScoutApm::Rack.transaction("Middleware", env) do
			@app.call(env)
		end
	end
end
