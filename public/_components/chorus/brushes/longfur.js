//	This file is part of the "Chorus" project, and is distributed under the MIT License.
//	Copyright (c) 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>

Chorus.createBrush('longfur', {
	init: function() {
		this.points = new Array();
		this.count = 0;
	},

	cancel: function() {
		this.cancelled = true;
	},

	strokeStart: function(x, y) {
	},

	stroke: function(x, y) {
		if (this.cancelled) return;
		
		var i, size, dx, dy, d, c = 4000;
		
		this.context.lineWidth = 1;
		this.context.globalCompositeOperation = 'source-over';
		
		this.context.strokeStyle = "rgba(" + this.color + ", 0.06)";
		this.points.push([x, y]);

		for (i = 0; i < this.points.length; i++)
		{
			size = -Math.random();
			dx = this.points[i][0] - this.points[this.count][0];
			dy = this.points[i][1] - this.points[this.count][1];
			d = dx * dx + dy * dy;

			if (d < (c*this.scale) && Math.random() > d / (c*this.scale))
			{
				this.context.beginPath();
				this.context.moveTo(this.points[this.count][0] + (dx * size), this.points[this.count][1] + (dy * size));
				this.context.lineTo(this.points[i][0] - (dx * size) + Math.random() * 20, this.points[i][1] - (dy * size) + Math.random() * 20);
				this.context.stroke();
			}
		}
		
		this.count++;
	},

	strokeEnd: function() {
	}
});
