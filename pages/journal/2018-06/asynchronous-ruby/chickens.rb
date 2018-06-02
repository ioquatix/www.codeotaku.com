require 'async/await'

class Coop
	include Async::Await
	# include Async::IO for sockets
	
	async def find_chickens(area_name)
		rand(5).times do |i|
			sleep rand
			
			puts "Found a chicken in the #{area_name}!"
		end
	end

	async def find_all_chickens
		# These methods all run at the same time.
		[
			find_chickens("garden"),
			find_chickens("house"),
			find_chickens("tree"),
		].sum(&:result)
	end
end

coop = Coop.new
puts "Found #{coop.find_all_chickens.result} chickens!"