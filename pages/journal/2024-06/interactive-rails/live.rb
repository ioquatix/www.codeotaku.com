require 'live/view'

class Clock < Live::View
	def bind(page)
		super
		
		# Create a new task that will update the clock every second:
		@task ||= Async do
			loop do
				sleep 1
				self.update!
			end
		end
	end
	
	def close
		if @task
			@task.stop
			@task = nil
		end
	end
	
	def render(builder)
		builder.inline_tag "p" do
			builder.text("The time is: #{Time.now}")
		end
	end
end