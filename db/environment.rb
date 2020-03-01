
require 'variant'
require 'relaxo'

# Configure the database connection:
DB = Relaxo.connect(
	File.join(__dir__, Variant.for(:database).to_s),
)

require 'journal'
