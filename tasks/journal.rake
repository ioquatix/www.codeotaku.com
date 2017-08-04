
namespace :journal do
	task :list => :environment do
		require 'journal/article'
		
		DB.current do |dataset|
			puts Journal::Article.all(dataset).to_a.inspect
		end
	end
	
	task :import => :environment do
		comments = JSON.parse(File.read("db/comments.json"), symbolize_names: true)
		users = JSON.parse(File.read("db/users.json"), symbolize_names: true)
		users_by_id = {}
		users_by_email = {}
		
		puts users.first.keys.inspect
		# [:id, :icon, :name, :from, :email, :website, :password, :access]
		puts comments.first.keys.inspect
		# [:id, :node, :posted_on, :visible, :body, :body_html, :user_id]
		
		DB.commit(message: "Import Users") do |changeset|
			puts "Importing #{users.count} users..."
			users.each do |existing|
				puts "Importing user #{existing[:id]} #{existing[:name]}"
				
				if existing[:name].empty? or existing[:email].empty?
					puts "Skipping #{existing.inspect}"
					next
				end
				
				if existing_user = users_by_email[existing[:email]]
					puts "Duplicate email #{existing.inspect}"
					users_by_id[existing[:id]] = existing_user
					next
				end
				
				users_by_id[existing[:id]] = existing
				users_by_email[existing[:email]] = existing
				
				user = existing[:related] = Journal::User.create(changeset)
				user.assign(existing, [:name, :from, :email, :website, :password])
				user.admin = existing[:access] == 'admin'
				
				user.save(changeset)
			end
		end
		
		DB.commit(message: "Import Comments") do |changeset|
			puts "Importing #{comments.count} comments..."
			comments.each do |existing|
				puts "Importing comment #{existing[:id]} #{existing[:node]}"
				
				if existing[:body].empty?
					puts "Skipping #{existing.inspect}"
					next
				end
				
				comment = existing[:related] = Journal::Comment.create(changeset)
				existing[:created_at] = existing[:posted_on]
				existing[:body_text] = existing[:body]
				
				comment.assign(existing, [:node, :created_at, :visible, :body_text, :body_html])
				if existing_user = users_by_id[existing[:user_id]]
					comment.user = existing_user[:related]
				else
					puts "Could not find user #{existing[:user_id]}"
				end
				
				puts comment.attributes.inspect
				
				comment.save(changeset)
			end
		end
	end
	
	namespace :users do
		task :create => :environment do
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
	end
end
