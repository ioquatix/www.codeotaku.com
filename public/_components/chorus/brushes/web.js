//	This file is part of the "Chorus" project, and is distributed under the MIT License.
//	Copyright (c) 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>

Chorus.createBrush('web', {
	context: null,

	prevx: null, prevy: null,

	points: null, count: null,

	init: function(context) {
		this.context = context;
		this.points = new Array();
		this.count = 0;
		this.cancelled = false;
	},

	cancel: function() {
		this.cancelled = true;
	},

	strokeStart: function(x, y) {
		this.prevx = x;
		this.prevy = y;
	},

	stroke: function(x, y) {
		if (this.cancelled) return;
		
		var i, dx, dy, d;

		this.points.push([ x, y ]);

		this.context.lineWidth = 1;
		this.context.globalCompositeOperation = 'source-over';
		
		this.context.strokeStyle = "rgba(" + this.color + ",0.5)";
		this.context.beginPath();
		this.context.moveTo(this.prevx, this.prevy);
		this.context.lineTo(x, y);
		this.context.stroke();

		this.context.strokeStyle = "rgba(" + this.color + ",0.1)";

		for (i = 0; i < this.points.length; i++) {
			dx = this.points[i][0] - this.points[this.count][0];
			dy = this.points[i][1] - this.points[this.count][1];
			d = dx * dx + dy * dy;

			if (d < 2500 && Math.random() > 0.9) {
				this.context.beginPath();
				this.context.moveTo(this.points[this.count][0], this.points[this.count][1]);
				this.context.lineTo(this.points[i][0], this.points[i][1]);
				this.context.stroke();
			}
		}

		this.prevx = x;
		this.prevy = y;

		this.count++;
	},

	strokeEnd: function() {
	}
});
