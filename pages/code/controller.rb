
prepend Actions

on 'index' do |request|
	@brush = request.params['brush'] || 'ruby'
	
	if request.post?
		@code = request.params['code']
	else
		@code = File.read(__FILE__)
	end
end
