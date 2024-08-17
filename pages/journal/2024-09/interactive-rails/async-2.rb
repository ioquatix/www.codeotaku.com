require 'async'
require 'net/http'

Async do
	# Both the HTTP operation and the `puts` operation are asynchronous.
	puts Net::HTTP.get(URI('https://httpbin.org/uuid'))
end