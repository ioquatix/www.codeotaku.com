require 'async'
require 'async/io'
require 'net/http'

# Inject shims:
Net::HTTP.include(Async::IO)

Async do
	# While the HTTP operation is asynchronous, the `puts` operation is synchronous.
	puts Net::HTTP.get(URI('https://httpbin.org/uuid'))
end