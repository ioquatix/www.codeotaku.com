
require 'relaxo/model'

require 'trenni/sanitize'
require 'markly'

module Journal
	class Fragment < Trenni::Sanitize::Filter
		ALLOWED_TAGS = {
			'h1' => [],
			'h2' => [],
			'h3' => [],
			'h4' => [],
			'h5' => [],
			'h6' => [],
			'p' => [],
			'strong' => [],
			'em' => [],
			'a' => ['href'],
			'abbr' => [],
			'img' => ['src', 'alt', 'width', 'height'],
			'pre' => [],
			'code' => ['class'],
			'blockquote' => [],
			'ol' => [],
			'ul' => [],
			'li' => [],
			'dl' => [],
			'dt' => [],
			'dd' => [],
		}.freeze
		
		def filter(node)
			if attributes = ALLOWED_TAGS[node.name]
				node.limit_attributes(attributes)
			else
				# Skip the tag, and all contents
				node.skip!(ALL)
			end
		end
		
		def doctype(string)
		end
		
		def instruction(string)
		end
	end
	
	class Comment
		include Relaxo::Model
		
		property :id, UUID
		
		property :node
		property :user, BelongsTo[User]
		property :parent, BelongsTo[Comment]
		
		property :created_at, Attribute[DateTime]
		property :updated_at, Attribute[DateTime]
		
		property :body_text
		property :body_html
		
		def self.format_body_html(text)
			if text
				html = Markly.parse(text).to_html
				
				return Fragment.parse(html).output
			end
		end
		
		def body=(text)
			self.body_text = text
			self.body_html = self.class.format_body_html(text)
		end
		
		property :visible, Attribute[Boolean]
		
		view :all, :type, index: unique(:id)
		
		def editable_by(user)
			if user
				return true if user.admin?
				
				# Cannot edit moderated comment.
				return false if self.visible?
				
				return true if self.user == user
			end
			
			return false
		end
		
		def visible_to(user)
			self.visible? || self.editable_by(user)
		end
		
		def self.for_node(dataset, node, user = nil)
			self.by_node(dataset, node: node).lazy.select{|comment| comment.visible_to(user)}
		end
		
		view :by_node, :type, 'by_node', unique(:node), index: unique(:created_at, :id)
	end
end