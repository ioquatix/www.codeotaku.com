require 'csv'

# Get the system load averages:
def load_averages
	`uptime`.split(' ')[-3..-1].map(&:to_f)
end

run do |env|
	request = Rack::Request.new(env)
	
	body = proc do |stream|
		csv = CSV.new(stream)
		
		csv << ['Time', '1m Load Average', '5m Load Average', '15m Load Average']
		
		while true
			csv << [Time.now.to_s, *load_averages]
			sleep(1)
		end
	end
	
	[200, {'content-type' => 'text/csv'}, body]
end
