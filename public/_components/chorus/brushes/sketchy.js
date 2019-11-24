//	This file is part of the "Chorus" project, and is distributed under the MIT License.
//	Copyright (c) 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>

Chorus.createBrush('sketchy', {
	init: function() {
		this.points = new Array();
		this.count = 0;
		
		this.prevx = null;
		this.prevy = null;
	},

	destroy: function() {
	},

	strokeStart: function(x, y) {
		this.prevx = x;
		this.prevy = y;
	},

	stroke: function(x, y) {
		if (this.cancelled) return;
		
		var i, dx, dy, d, c = 8000;

		this.points.push([ x, y ]);

		this.context.lineWidth = 1;
		this.context.globalCompositeOperation = 'source-over';

		this.context.strokeStyle = "rgba(" + this.color + ", 0.3)";
		this.context.beginPath();
		this.context.moveTo(this.prevx, this.prevy);
		this.context.lineTo(x, y);
		this.context.stroke();

		this.context.strokeStyle = "rgba(" + this.color + ", 0.08)";

		for (i = 0; i < this.points.length; i++)
		{
			dx = this.points[i][0] - this.points[this.count][0];
			dy = this.points[i][1] - this.points[this.count][1];
			d = dx * dx + dy * dy;

			if (d < (c*2*this.scale) && Math.random() > d / (c*this.scale))
			{
				this.context.beginPath();
				this.context.moveTo(this.points[this.count][0] + (dx * 0.3), this.points[this.count][1] + (dy * 0.3));
				this.context.lineTo(this.points[i][0] - (dx * 0.3), this.points[i][1] - (dy * 0.3));
				this.context.stroke();
			}
		}

		this.prevx = x;
		this.prevy = y;

		this.count ++;
	},

	strokeEnd: function() {
	}
});
