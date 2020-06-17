# Read the existing markup from disk:
root = Markly.parse(File.read(readme_path))
node = root.first_child

# Skip first heading:
node = node.next if node.type == :heading

# Generates a new badge for the specified URL.
def badge_for(repository_url)
	"[![Development Status](#{repository_url}/workflows/Development/badge.svg)](#{repository_url}/actions?workflow=Development)"
end

# @returns [Boolean] If the node is a badge, a link which contains an image.
def badge?(node)
	return false unless node.type == :link
	return node.all?{|child| child.type == :image}
end

# @returns [Boolean] If the node contains at least one {badge?}.
def badges?(node)
	node.any?{|child| badge?(child)}
end

# Find the top level node which contains the badges:
while !badges?(node)
	node = node.next
end

# Replace the node with the updated badge:
replacement = Markly.parse(badge_for(repository_url))
node = node.replace(replacement.first_child)

# Write the updated markdown to disk:
node.write(readme_path, root.to_markdown)
