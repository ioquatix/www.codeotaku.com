/* 
	This file is part of the "Chorus" project, and is distributed under the MIT License.
	For more information, please see http://www.oriontransfer.co.nz/javascript/chorus

	Copyright (c) 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	THE SOFTWARE.
*/

function Chorus (canvas) {
	this.canvas = canvas;
	this.context = canvas.getContext("2d");
	this.brushes = [];
}

Chorus.Brushes = {}

Chorus.Brush = function (context) {
	this.cancelled = false;
	this.scale = 1.0;
	this.context = context;
}

Chorus.Brush.prototype.cancel = function() {
	this.cancelled = true;
}

Chorus.Brush.prototype.setScale = function(scale) {
	this.scale = scale;
}

Chorus.createBrush = function(name, implementation) {
	Chorus.Brushes[name] = function(context) {
		Chorus.Brush.call(this, context);
	};
	
	var clone = function() {}
	clone.prototype = Chorus.Brush.prototype;
	
	Chorus.Brushes[name].prototype = new clone;
	
	for (key in implementation) {
		Chorus.Brushes[name].prototype[key] = implementation[key];
	}
}

Chorus.createBackground = function(drawFunction) {
	var container = $('<div id="chorus-background" style="margin: 0; padding: 0; z-index: -1; position: fixed;"></div>')
	$('body').prepend(container);

	var canvas = document.createElement("canvas");
	canvas.width = window.innerWidth;
	canvas.height = window.innerHeight;
	container.append(canvas);

	if (!canvas.getContext) return;
	
	var context = canvas.getContext("2d");
	var chorus = new Chorus(canvas);
	
	var onWindowResize = null;
	if (drawFunction) {
		onWindowResize = function() {
			/* change the size */
			canvas.width = window.innerWidth;
			canvas.height = window.innerHeight;
			
			/* call the draw callback */
			drawFunction(chorus);
		};
	} else {
		onWindowResize = function() {
			/* make a copy */
			var canvasCopy = document.createElement("canvas");
			canvasCopy.width = canvas.width;
			canvasCopy.height = canvas.height;
			canvasCopy.getContext("2d").drawImage(canvas, 0, 0);

			/* change the size */
			canvas.width = window.innerWidth;
			canvas.height = window.innerHeight;

			/* draw the copy */
			context.drawImage(canvasCopy, 0, 0);
		}
	}
	
	window.addEventListener('resize', onWindowResize, false);
	onWindowResize(null);
	
	return chorus;
}

Chorus.cubicInterpolate = function(t, a, b, c, d) {
	function SUB(a, b) {
		return [a[0] - b[0], a[1] - b[1]];
	}

	function MUL(a, b) {
		return [a[0] * b, a[1] * b];
	}

	function ADD(a, b, c, d) {
		return [a[0] + b[0] + c[0] + d[0], a[1] + b[1] + c[1] + d[1]];
	}

	var p = SUB(SUB(d, c), SUB(a, b));
	var q = SUB(SUB(a, b), p);
	var r = SUB(c, a);
	var s = b;

	return ADD(MUL(p, t*t*t), MUL(q, t*t), MUL(r, t), s);
}

Chorus.interpolate = function(coords, t) {
	var i = Math.floor(t);
	var a = coords[(i - 1 + coords.length) % coords.length];
	var b = coords[i];
	var c = coords[(i + 1) % coords.length];
	var d = coords[(i + 2) % coords.length];
	
	return Chorus.cubicInterpolate(t - i, a, b, c, d);
}

Chorus.permute = function(coords) {
	var permuted = [];
	var f = 20;
	
	for (var i = 0; i < coords.length; i++) {
		permuted.push([
			coords[i][0] + (Math.random() * f),
			coords[i][1] + (Math.random() * f)
		]);
	}
	
	return permuted;
}

Chorus.smooth = function(coords, subdivisions) {
	if (coords.length >= 3) {
		var smoothed = [];
		
		for (var i = 0; i < coords.length - 1; i++) {
			for (var j = 0; j < subdivisions; j++) {
				var t = j / subdivisions;
				
				smoothed.push(Chorus.interpolate(coords, i + t));
			}
		}
		
		smoothed.push(coords[coords.length - 1]);
		
		return smoothed;
	}
	
	return coords;
}

Chorus.prototype.stroke = function(brush, coords, interpolate, callback) {
	if (interpolate)
		coords = Chorus.smooth(coords, interpolate);
	
	function S(c) {
		brush.stroke(c[0], c[1]);
	}
	
	function Sf(c) {
		brush.strokeEnd(c[0], c[1]);
		
		if (callback)
			callback();
	}
	
	brush.strokeStart(coords[0][0], coords[0][1])
	
	var i;
	for (i = 0; i < coords.length; i++) {
		setTimeout(S.bind(this, coords[i]), i * 20);
	}
	
	setTimeout(Sf.bind(this, coords[i-1]), i * 20);
}

Chorus.prototype.draw = function(brush, strokes, options) {
	var last = function(){};
	
	for (var i = 0; i < strokes.length; i++) {
		var color = [0, 0, 0], coords;
		color[0] = Math.floor(strokes[i][0][0] * 255);
		color[1] = Math.floor(strokes[i][0][1] * 255);
		color[2] = Math.floor(strokes[i][0][2] * 255);
		
		if (options.transform) {
			coords = [];
			
			for (var j = 0; j < strokes[i][1].length; j++) {
				coords.push(options.transform(strokes[i][1][j]))
			}
		} else {
			coords = strokes[i][1];
		}
		
		last = (function(color, coords, last) {
			brush.color = color;
			
			this.stroke(brush, coords, options.interpolate, last);
		}).bind(this, color, coords, last);
	}
	
	last();
}

Chorus.prototype.cancel = function() {
	for (var i = 0; i < this.brushes.length; i++) {
		this.brushes[i].cancel();
		
		if (this.brushes[i].destroy)
			this.brushes[i].destroy();
	}
	
	this.brushes = [];
}

Chorus.prototype.getBrush = function(name, callback) {
	var brush = new Chorus.Brushes[name](this.context);
	
	brush.init();	
	this.brushes.push(brush);
	callback(brush);
}

Chorus.translate = function(t, f) {
	return function(c) {
		if (f) {
			c = f(c);
		}
		
		return [c[0] + t[0], c[1] + t[1]]
	}
}

Chorus.scale = function(t, f) {
	return function(c) {
		if (f) {
			c = f(c);
		}
		
		return [c[0] * t[0], c[1] * t[1]]
	}
}
