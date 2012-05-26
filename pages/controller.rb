
require_local 'comments'
require 'digest/sha1'

def on_comments_preview(path, request)
	body = request[:body]
	
	formatted_html = Comment.format_body_html(body)

	return {:status => :success, :content => formatted_html}
end

def on_comments_edit(path, request)
	comment = Comment.get(request[:id].to_i)

	if comment && (request.controller.admin? || request.controller.user == comment.user)
		fields = {
			:id => comment.id,
			:body => comment.body,
			:posted_by => comment.user.name,
			:email => comment.user.email,
			:website => comment.user.website,
			:from => comment.user.from,
			:icon => comment.user.icon
		}
		
		return {:status => :success, :content => fields.to_json, :type => "application/json"}
	end
	
	return :unauthorized
end

def on_comments_update(path, request)
	return :unauthorized unless request.post? and request.controller.admin?
	
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
		
		return :success
	end
	
	return :unauthorized
end

def on_comments_create(path, request)
	return :unauthorized unless request.post?

	user = nil

	if request.controller.user
		LOG.debug("Posting comment from logged in user.")
		user = request.controller.user
	else
		LOG.debug("Posting comment from guest user.")
		# If we are posting anonymously, try and find user by name and email..
		user = User.first(:name => request[:posted_by])
		
		if user
			unless user.guest? && user.email == request[:email]
				LOG.debug("User name is not guest (#{user.access}), or email is not correct (#{user.email} != #{request[:email]}).")
				return :unauthorized
			end
		else
			LOG.debug("Creating new user for #{request[:posted_by]}")
			user = User.new
		end
	end
	
	user.name = request[:posted_by]
	user.icon = request[:icon]
	user.from = request[:from]
	user.email = request[:email]
	user.website = request[:website]
	user.save

	# Security - can't log in as admin this way, under any circumstance.
	unless user.admin? || request.session['user'] != nil
		LOG.debug("Logging user #{user.name} [#{user.id}] in.")
		request.session['user'] = user.id
	end
	
	comment = Comment.new
	comment.user = user
	
	comment.node = request[:node]
	comment.posted_on = DateTime.now
	
	if user.admin?
		LOG.debug("Comment is visible, because user was admin.")
		comment.visible = true
	else
		LOG.debug("Comment is awaiting moderation.")
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
		LOG.error("Could not send notification: #{$!.inspect}")
	end
	
	return {:status => :success, :content => comment.to_json(:only => [:id]), :type => "application/json"}
end

def on_comments_toggle(path, request)
	return :forbidden unless request.post?
	
	if request.controller.admin?
		comment = Comment.first(:id => request[:id])
		comment.visible = !comment.visible
		comment.save
		
		return :success
	else
		return :forbidden
	end
end

def on_comments_delete(path, request)
	return :forbidden unless request.post?
	
	if request.controller.admin?
		comment = Comment.first(:id => request[:id])
		comment.destroy!
		
		return :success
	else
		return :forbidden
	end
end

def on_login_salt(path, request)
	salt = Digest::SHA1.hexdigest(Time.now.to_s + rand.to_s)
	
	request.session['login_salt'] = salt
	
	return {:code => :success, :content => salt}
end

def on_login(path, request)
	return permission_denied unless request.post?
	
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
		
		return {:redirect => request.referer}
	else
		LOG.debug("User #{name} (#{password.inspect} / #{password_hash.inspect}) was not logged in.")
		return :unauthorized
	end
end

def on_logout(path, request)
	request.session['user'] = nil
	return :success
end

def process!(path, request)
	request.controller do
		@session = request.session
		
		# Lazy load the user object if required by the view
		def user
			if defined? @user
				@user
			else
				if @session['user']
					@user ||= User.first(:id => @session['user'])
				else
					@user = nil
				end
			end
		end
		
		def admin?
			if user
				user.admin?
			else
				false
			end
		end
	end
	
	return passthrough(path, request)
end

