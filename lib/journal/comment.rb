
require 'relaxo/model'

require 'trenni/sanitize'
require 'kramdown'

module Journal
	class Fragment < Trenni::Sanitize::Filter
		ALLOWED_TAGS = {
			'em' => [],
			'strong' => [],
			'p' => [],
			'img' => ['src', 'alt', 'width', 'height'],
			'a' => ['href'],
			'pre' => [],
			'code' => ['class'],
		}.freeze
		
		def filter(node)
			if attributes = ALLOWED_TAGS[node.name]
				node.tag.attributes.slice!(*attributes)
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
			html = Kramdown::Document.new(text, input: 'GFM', syntax_highlighter: nil).to_html
			
			return Fragment.parse(html).output
		end
		
		def body=(text)
			self.body_text = text
			self.body_html = self.class.format_body_html(text)
		end
		
		property :visible, Attribute[Boolean]
		
		view :all, [:type], index: [:id]
		
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
		
		view :by_node, [:type, 'by_node', :node], index: [[:created_at, :id]]
		# view :by_user, [:type, 'by_user', :user], index: [[:created_at, :id]]
	end
end