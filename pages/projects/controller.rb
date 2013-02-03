
include Direct

def on_redirect(path, request)
	links = Links.index(BASE_PATH, Path.new)
	
	name = path.components[-2]
	
	link = links.find{|link| link.name == name}
	
	if link and link.href
		if link.href =~ /^\//
			redirect! (URI_PATH + link.href).to_s
		else
			redirect! link.href
		end
	else
		respond! 404
	end
end

def process!(path, request)
	passthrough(path, request)
end
