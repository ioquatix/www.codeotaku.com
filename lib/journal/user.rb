
require 'relaxo/model'
require 'relaxo/model/properties/bcrypt'

module Journal
	class User
		include Relaxo::Model
		
		property :id, UUID
		
		property :name
		property :password, Optional[Attribute[BCrypt::Password]]
		
		property :from
		property :email
		property :website
		
		property :created_at, Attribute[DateTime]
		property :updated_at, Attribute[DateTime]
		
		property :admin, Attribute[Boolean]
		
		view :all, :type, index: unique(:id)
		view :by_email, :type, 'by_email', index: unique(:email)
		
		def self.authenticate(dataset, email, password)
			binding.irb
			if user = fetch_by_email(dataset, email: email)
				return user if user.password == password
			end
		end
		
		def self.build(dataset, params)
			email = params['email']
			
			if user = self.fetch_by_email(dataset, email: email)
				return nil if user.admin?
			else
				user = self.create(dataset, email: email, created_at: DateTime.now)
			end
			
			user.assign(params, [:name, :from, :website])
			
			# unless user.password?
			# 	user.generate_password
			# end
			
			return user
		end
		
		private
		
		PASSWORD_CHARACTERS = [*('a'..'z'), *('A'..'Z'),*('2'..'9'),'@', '$', '%', '&', '*', ':'].flatten - ['i', 'l', 'I', 'L', 'j', 'J']
		
		def generate_password(size = 16)
			self.password = (0..size).map{PASSWORD_CHARACTERS.sample}.join
			
			self.jobs << Notification::PasswordChanged
		end
	end
end