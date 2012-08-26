
Tileshift.addLevel({
	name: 'test',
	description: 'Find the key to open the chest!',
	difficulty: 1.0,
	
	Level: function(config, controller) {
		this.resources = new ResourceLoader(controller.resources);
		this.resources.loadAudio('Player.MOVE', 'effects/Step.wav');
		
		this.onBegin = function() {
			var map = new TileMap([20, 30]);
			
			for (var r = 0; r < map.size[0]; r += 1) {
				for (var c = 0; c < map.size[1]; c += 1) {
					map.set([r, c], new Tile(0, Tile.FLOOR));
				}
			}

			for (var i = 10; i < 16; i += 1)
				map.set([i, 20], null);
			
			for (var i = 15; i < 20; i += 1)
				map.set([15, i], null);

			map.set([10, 15], new Tile(0, Tile.START));
			map.set([18, 28], new Tile(0, Tile.END, Tile.END));

			this.mapRenderer = new TileMapRenderer(this.resources, map.size);
			controller.resizeCanvas(this.mapRenderer.pixelSize());

			this.searchRenderer = new SearchRenderer(this.mapRenderer.scale);

			this.gameState = new GameState(map, [10, 15]);
			
			this.redraw();
		}
		
		this.onFinish = function() {
			if (this.interval) clearInterval(this.interval);
			
			this.interval = null;
		}
		
		this.onTick = function() {
			var generator = new Generator(this.gameState.map, this.gameState.events);
			generator.score(this.gameState.map);
			
			this.searchRenderer.search = generator.search;
			
			this.redraw();
		}
		
		this.redraw = function() {
			var context = controller.canvas.getContext('2d');
			this.mapRenderer.display(context, [this.gameState.map, this.gameState]);
			this.searchRenderer.display(context);
		}
		
		this.onUserEvent = function(event) {
			if (this.gameState.isValidEvent(event)) {
				this.gameState.pushEvent(event);
				
				this.onTick();
			}
			
			this.redraw();
		}
		
		this.resources.loaded(controller.runLevel.bind(controller, this));
	},
	
	start: function(controller) {
		return new this.Level(this, controller);
	},
});