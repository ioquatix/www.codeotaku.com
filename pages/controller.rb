prepend Actions

RESOLVER = Live::Resolver.allow(Live::DeveloperView, Live::ClockView)

on :live do |request|
	websocket = Async::WebSocket::Adapters::Rack.open(request.env) do |connection|
		Live::Page.new(RESOLVER).run(connection)
	end
	
	respond?(websocket)
	
	fail!
end
