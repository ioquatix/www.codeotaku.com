cache = {}

expect do
	fetch_and_update(resource, cache)
end.to only_modify(cache)