
prepend Actions

on 'queue' do |request, path|
	fail! :unauthorized unless @user&.admin?

	@comments = Journal::Comment.all(DB.current).lazy.select{|comment| !comment.visible?}
end

on '**/comments/preview' do |request, path|
	body = request[:body]
	
	formatted_html = Journal::Comment.format_body_html(body)
	
	succeed! content: formatted_html, type: "text/html"
end

on '**/comments/edit' do |request, path|
	comment = Journal::Comment.fetch_all(DB.current, id: request.params['id'])

	if comment&.editable_by(@user)
		fields = {
			:id => comment.id,
			:body => comment.body_text,
			:name => comment.user.name,
			:email => comment.user.email,
			:website => comment.user.website,
			:from => comment.user.from,
		}
		
		succeed! content: fields.to_json, type: "application/json"
	end
	
	fail! :unauthorized
end

on '**/comments/update' do |request, path|
	fail! unless request.post?
	
	@comment = Journal::Comment.fetch_all(DB.current, id: request.params['id'])
	
	fail! :unauthorized unless @comment.editable_by(@user)
	
	DB.commit(message: "Update Comment") do |dataset|
		# We only update the user if it's the same one as the comment.
		if @comment.user == @user
			@user.updated_at = DateTime.now
			@user.assign(request.params, [:name, :email, :website, :from])
			@user.save(dataset)
		end
		
		@comment.updated_at = DateTime.now
		@comment.body = request.params['body']
		@comment.save(dataset)
	end
	
	succeed!
end

on '**/comments/create' do |request, path|
	@comment = Journal::Comment.create(DB.current, :created_at => DateTime.now)
	
	if request.post?
		@comment.body = request[:body]
		@comment.node = request[:node]
		
		DB.commit(message: "Create Comment") do |dataset|
			@user ||= Journal::User.build(dataset, request.params)
			@user.updated_at = DateTime.now
			
			@user.save(dataset)
			
			@comment.user = @user
			@comment.save(dataset)
		end
		
		begin
			notification = Mail.new(
				to: "samuel@oriontransfer.net",
				from: @user.email,
				subject: "New Comment from #{@user.name}",
			)
			
			notification.body = request.referer + "\n\n" + @comment.body_text
			
			notification.deliver!
		rescue
			$stderr.puts "Failed to send notification: #{$!}"
		end
		
		request.session['user_id'] = @user.id
		
		redirect! request.referer
	end
end

on '**/comments/toggle' do |request, path|
	fail! unless request.post? and @user&.admin?
	
	@comment = Journal::Comment.fetch_all(DB.current, id: request.params['id'])
	
	DB.commit(message: "Toggle Visiblilty") do |changeset|
		@comment.visible = !@comment.visible
		@comment.updated_at = DateTime.now
		@comment.save(changeset)
	end
	
	succeed!
end

on '**/comments/delete' do |request, path|
	fail! unless request.post?
	
	@comment = Journal::Comment.fetch_all(DB.current, id: request.params['id'])
	
	if @comment&.editable_by(@user)
		DB.commit(message: "Delete Comment") do |dataset|
			@comment.delete(dataset)
		end
		
		succeed!
	else
		fail! :unauthorized
	end
end

on '**/login' do |request, path|
	fail! unless request.post?
	
	name = request[:username]
	password = request[:password]
	
	if user = Journal::User.authenticate(DB.current, name, password)
		request.session['user_id'] = user.id
		
		redirect! request.referer
	else
		fail! :unauthorized
	end
end

on '**/logout' do |request, path|
	request.session['user_id'] = nil
	
	redirect! request.referrer
end

on '**' do |request, path|
	if user_id = request.session['user_id']
		@user = Journal::User.fetch_all(DB.current, id: user_id)
	else
		@user = nil
	end
end
