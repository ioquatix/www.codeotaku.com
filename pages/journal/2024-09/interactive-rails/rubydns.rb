upstream = Resolv::DNS.new

RubyDNS.run_server do
	match(/\.mydomain\.com\z/, :A) do |transaction|
		# The internal IP address of the server:
		transaction.respond!("10.0.0.80")
	end

	otherwise do |transaction|
		logger.info "Passing DNS request upstream..."
		transaction.passthrough!(upstream)
	end
end
