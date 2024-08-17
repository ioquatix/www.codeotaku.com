require 'live/view'

module Live
	class DeveloperView < View
		def initialize(...)
			super
			
			@data[:pid] ||= Process.ppid
		end
		
		def pid
			@data[:pid].to_i
		end
		
		def bind(page)
			super
			
			if self.pid != Process.ppid
				@data[:pid] = Process.ppid
				self.script("window.location.reload()")
				self.update!
			end
		end
		
		def render(builder)
		end
	end
end