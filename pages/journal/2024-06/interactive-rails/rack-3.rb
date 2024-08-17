# config.ru

run do |env|
	body = proc do |stream|
		100.downto(1) do |i|
			stream.write "#{i} bottles of beer on the wall,\n"
			sleep 1
			stream.write "#{i} bottles of beer.\n"
			sleep 1
			stream.write "Take one down, pass it around,\n"
			sleep 1
			stream.write "#{i-1} bottles of beer on the wall.\n"
			if i > 0
				sleep 1
				stream.write "\n"
			end
		end
	end
	
	[200, {'content-type' => 'text/plain'}, body]
end