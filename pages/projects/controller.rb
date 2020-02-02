
prepend Actions

LINKS = Utopia::Content::Links.new(BASE_PATH)

# API = RestClient::Resource.new('https://api.github.com', accept: 'application/vnd.github.v3+json')
# 
# def list_projects
# 	API.get('/orgs/kurocha/repos')
# end

on 'redirect' do |request, path|
	links = LINKS.index(Path.root)
	
	name = request['project']
	
	link = links.find{|link| link.name == name}
	
	if link and link.href
		redirect! link.href
	else
		respond! 404
	end
end
