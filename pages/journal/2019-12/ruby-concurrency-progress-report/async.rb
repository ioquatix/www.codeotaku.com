if production?
	def log(*arguments)
		# Non-blocking operation:
		post_to_remote_log_server(*arguments)
	end
else
	def log(*arguments)
		$stdout.puts(*arguments)
	end
end

# Is this non-blocking?
log("Hello World")
