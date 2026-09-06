require "protocol/http/middleware"
require "protocol/http/response"
require "utopia/application"

# Rack passes an environment hash and receives a response array:
rack_application = lambda do |environment|
	[200, {"content-type" => "text/plain"}, [environment["PATH_INFO"]]]
end

# Utopia uses Protocol::HTTP request and response objects directly:
Application = Utopia::Application.build do
	run Protocol::HTTP::Middleware.for do |request|
		Protocol::HTTP::Response[
			200,
			{"content-type" => "text/plain"},
			[request.path],
		]
	end
end
