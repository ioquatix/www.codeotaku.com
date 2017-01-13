
prepend Actions

require_relative 'comments'

require 'digest/sha1'
require 'json'

require 'promise'

LOG = Logger.new($stderr)

on 'queue' do |request, path|
	fail! unless @user.admin?

	@comments = Comment.all(:visible => false)
end

on '**/comments/preview' do |request, path|
	body = request[:body]
	
	formatted_html = Comment.format_body_html(body)
	
	succeed! content: formatted_html, type: "text/html"
end

on '**/comments/edit' do |request, path|
	comment = Comment.get(request[:id].to_i)

	if comment and (@user.admin? or @user == comment.user)
		fields = {
			:id => comment.id,
			:body => comment.body,
			:posted_by => comment.user.name,
			:email => comment.user.email,
			:website => comment.user.website,
			:from => comment.user.from,
			:icon => comment.user.icon
		}
		
		succeed! content: fields.to_json, type: "application/json"
	end
	
	fail! :unauthorized
end

on '**/comments/update' do |request, path|
	fail! unless request.post? and @user.admin?
	
	comment = Comment.get(request[:id].to_i)
	
	if comment
		comment.body = request[:body]
		comment.user.name = request[:posted_by]
		comment.user.email = request[:email]
		comment.user.website = request[:website]
		comment.user.from = request[:from]
		comment.user.icon = request[:icon]
		
		comment.user.save
		comment.save
		
		succeed!
	else
		fail!
	end
end

on '**/comments/create' do |request, path|
	fail! unless request.post?

	author = nil

	if @user
		# LOG.debug("Posting comment from logged in user.")
		author = @user
	else
		# LOG.debug("Posting comment from guest user.")
		# If we are posting anonymously, try and find user by name and email..
		author = User.first(:name => request[:posted_by])
		
		if author
			unless @author.guest? and @author.email == request[:email]
				# LOG.debug("User name is not guest (#{author.access}), or email is not correct (#{author.email} != #{request[:email]}).")
				fail! :unauthorized
			end
		else
			# LOG.debug("Creating new user for #{request[:posted_by]}")
			author = User.new
		end
	end
	
	author.name = request[:posted_by]
	author.icon = request[:icon]
	author.from = request[:from]
	author.email = request[:email]
	author.website = request[:website]
	author.save

	# Security - can't log in as admin this way, under any circumstance.
	unless author.admin? || request.session['user'] != nil
		# LOG.debug("Logging user #{user.name} [#{user.id}] in.")
		request.session['user'] = author.id
		@user = author
	end
	
	comment = Comment.new
	comment.user = author
	
	comment.node = request[:node]
	comment.posted_on = DateTime.now
	
	if user.admin?
		# LOG.debug("Comment is visible, because user was admin.")
		comment.visible = true
	else
		# LOG.debug("Comment is awaiting moderation.")
		comment.visible = false
	end

	comment.body = request[:body]
	comment.save

	begin
		notification = Mail.new do
			to "samuel@oriontransfer.org"
			from comment.user.email
			subject "New Comment from #{comment.user.name}"
			body request.referer + "\n\n" + comment.body
		end
		
		notification.deliver!
	rescue
		# LOG.error("Could not send notification: #{$!.inspect}")
	end
	
	succeed! content: comment.to_json(:only => [:id]), type: "application/json"
end

on '**/comments/toggle' do |request, path|
	fail! unless request.post? and @user.admin?
	
	comment = Comment.first(:id => request[:id])
	comment.visible = !comment.visible
	comment.save
		
	succeed!
end

on '**/comments/delete' do |request, path|
	fail! unless request.post? and @user.admin?
	
	comment = Comment.first(:id => request[:id])
	comment.destroy!
		
	succeed!
end

on '**/login/salt' do |request, path|
	salt = Digest::SHA1.hexdigest(Time.now.to_s + rand.to_s)
	
	request.session['login_salt'] = salt
	
	succeed! content: salt
end

on '**/login' do |request, path|
	fail! unless request.post?
	
	name = request[:username]
	password = request[:password]
	password_hash = request[:password_hash]
	
	user = User.first(:name => name)
	success = false
	
	if user && password_hash
		success = user.digest_authenticate(password_hash, request.session['login_salt'])
	elsif user && password
		success = user.plaintext_authenticate(password)
	end
	
	# If no login method was successful, nullify the user
	user = nil unless success
	
	if user
		request.session['user'] = user.id
		
		redirect! request.referer
	else
		# LOG.debug("User #{name} (#{password.inspect} / #{password_hash.inspect}) was not logged in.")
		
		fail! :unauthorized
	end
end

on '**/logout' do |request, path|
	request.session['user'] = nil
	
	succeed!
end

on '**' do |request, path|
	@session = request.session
	
	if user_id = request.session['user']
		@user = promise {User.first(:id => user_id)}
	end
end
