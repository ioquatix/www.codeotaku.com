
prepend Actions

on 'echo' do |request|
	if input = request.body
		succeed! body: input.body
	end
end
