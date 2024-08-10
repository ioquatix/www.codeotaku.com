upstream = Resolv::DNS.new

RubyDNS.run_server do
	match(/\.mydomain\.com\z/, :A) do |transaction|
		# The IP address of the server in my garage:
		transaction.respond!("10.0.0.80")
	end

	otherwise do |transaction|
		logger.info "Passing DNS request upstream..."
		transaction.passthrough!(upstream)
	end
end
