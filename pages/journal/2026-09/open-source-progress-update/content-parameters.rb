require "protocol/content"

parameters = Protocol::Content::Parameters.build do
	nested "user", required: true do
		field "name", String, required: true
		field "age", Integer
		field "status", enumeration("draft", "published")

		upload "avatar",
			accept: ["image/jpeg", "image/png"],
			size_limit: 5 * 1024 * 1024
	end
end

result = parameters.parse(media_type, input)
