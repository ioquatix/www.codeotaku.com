
rack 'www.codeotaku.com', :self_signed do
	root {File.realpath(__dir__)}
	config_path {::File.expand_path("config.ru", root)}
	
	# ssl_certificate_path '/etc/letsencrypt/live/www.codeotaku.com/fullchain.pem'
	# ssl_private_key_path '/etc/letsencrypt/live/www.codeotaku.com/privkey.pem'
end
