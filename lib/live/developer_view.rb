require 'live/view'

module Live
	class DeveloperView < View
		def initialize(...)
			super
			
			@data[:pid] ||= Process.pid
		end
		
		def pid
			@data[:pid].to_i
		end
		
		def bind(page)
			super
			
			if self.pid != Process.pid
				@data[:pid] = Process.pid
				self.script("window.location.reload()")
				self.update!
			end
		end
		
		def render(builder)
		end
	end
end