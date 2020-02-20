
def create
	call 'utopia:environment'
	
	require 'tty/prompt'
	
	prompt = TTY::Prompt.new
	
	name = prompt.ask("Email address:", default: 'admin')
	password = prompt.mask("Login password:")
	
	DB.commit(message: "New User") do |dataset|
		@user = Journal::User.create(dataset)
		
		@user.assign(email: email, password: password)
		
		@user.save(dataset)
	end
end
