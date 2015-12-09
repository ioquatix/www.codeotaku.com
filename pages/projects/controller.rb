
on 'redirect' do |request, path|
	links = Utopia::Content::Links.index(BASE_PATH, Path.root)
	
	name = request['project']
	
	link = links.find{|link| link.name == name}
	
	if link and link.href
		redirect! link.href
	else
		respond! 404
	end
end
