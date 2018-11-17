
prepend Actions

on 'echo' do |request|
	if body = request.body
		succeed! body: body
	end
end
