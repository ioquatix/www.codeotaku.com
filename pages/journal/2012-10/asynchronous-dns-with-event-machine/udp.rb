# `message` is the outgoing DNS request. `servers` is an array of potential
# upstream servers who might be able to provide an answer.
def initialize(message, servers, options = {}, &block)
	@message = message
	@packet = message.encode
	
	@servers = servers.dup
	
	# We select the protocol based on the size of the data:
	if @packet.bytesize > UDP_TRUNCATION_SIZE
		@servers.delete_if{|server| server[0] == :udp}
	end
	
	# Measured in seconds:
	@timeout = options[:timeout] || 5
	
	@logger = options[:logger]
end
