
require 'dm-core'
require 'dm-migrations'
require 'dm-aggregates'
require 'dm-serializer'

require 'base64'
require 'digest/sha1'

require 'sanitize'
require 'redcloth'

# DataMapper::Logger.new(STDOUT, :debug)
DataMapper.setup(:comments, "sqlite3:#{File.dirname(__FILE__)}/comments.sqlite3")

def secure_digest(key,salt="")
	return Digest::SHA1.hexdigest(key+salt)+salt
end

class Comment
 include DataMapper::Resource

	def self.default_repository_name
		:comments
	end

	property :id,         Serial
	property :node,       String, :index => true
	property :posted_on,  DateTime
	property :visible,    Boolean
	property :body,       Text
	property :body_html,  Text

	belongs_to :user
	
	def self.format_body_html(text)
		config = Sanitize::Config::BASIC
		
		codify = lambda do |env|
			node = env[:node]
			if node.name == "pre" || node.name == "code"
				klass = (node['class'] || '').downcase.gsub(/[^a-z\-0-9 ]/, "")
				
				Sanitize.clean_node!(node, config)
				
				node['class'] = klass
				
				{:whitelist => true, :attr_whitelist => ['class']}
			end
		end
		
		config_base = config.merge(:transformers => codify)
		Sanitize.clean(RedCloth.new(text).to_html, config_base)
	end
	
	def body=(text)
		attribute_set(:body, text)
		attribute_set(:body_html, self.class.format_body_html(text))
	end
end

class User
	include DataMapper::Resource

	def self.default_repository_name
		:comments
	end

	property :id,         Serial
	property :icon,       String
	property :name,       String, :index => true
	property :from,       String
	property :email,      String
	property :website,    String

	property :password,   String
	property :access,     String, :default => 'guest'
	
	has n, :comments
	
	def password=(pw)
		attribute_set(:password, secure_digest(pw))
	end
	
	def sha1_hexdigest
		if pw_sha1.kind_of? String
			digest = pw_sha1.sub("{SHA1}", "")
			
			return nil if digest.empty?
			
			return Base64.decode64(digest).unpack("H*").first
		else
			return nil
		end
	end
	
	def digest_authenticate(login_digest, login_salt)
		return false if password == nil
		
		Utopia::LOG.debug("digest_auth: digest = #{login_digest} salt = #{login_salt} password = #{password}")

		return login_digest == secure_digest(login_salt + password)
	end
	
	def plaintext_authenticate(pw)
		return false if password == nil
		
		return secure_digest(pw) == password
	end
	
	def admin?
		access == "admin"
	end
	
	def guest?
		access == "guest"
	end
end

DataMapper.auto_upgrade!(:comments)
