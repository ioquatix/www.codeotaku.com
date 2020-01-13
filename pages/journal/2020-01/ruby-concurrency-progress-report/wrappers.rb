# HTTP.rb gem using explicit injection:
wrappers = {socket_class: Async::IO::TCPSocket, ssl_socket_class: Async::IO::SSLSocket}
response = HTTP.get(uri, wrappers)

# Net::HTTP using monkey patching injection:
Net::HTTP.include(Async::IO)
response = Net::HTTP.get(uri)
