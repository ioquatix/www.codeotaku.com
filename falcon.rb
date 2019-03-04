
rack 'www.codeotaku.com' do
	root __dir__
	
	ssl_certificate_path '/etc/letsencrypt/live/www.codeotaku.com/fullchain.pem'
	ssl_private_key_path '/etc/letsencrypt/live/www.codeotaku.com/privkey.pem'
end
