
require 'relaxo/model'

module Journal
	class Article
		include Relaxo::Model
		
		property :id, UUID
		
		property :name
		
		property :created_date, Attribute[Date]
		
		view :all, [:type], index: [:id]
		
		view :by_date, [:type, 'by_date'], index: [[:created_date, :id]]
	end
end
