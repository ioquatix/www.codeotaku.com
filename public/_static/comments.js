
function AggregateCallback (timeout, enforce, callback) {
	this.timeout = timeout;
	this.enforce = enforce;
	
	this.callback = callback;
	
	this.timer = null;
	this.fired = null;
}

AggregateCallback.prototype.fire = function () {
	this.fired = new Date();
	this.callback();
}

AggregateCallback.prototype._expired = function () {
	// Returns true if we have been fired further than maxTimeout in the past.
	return !this.fired || ((new Date() - this.fired) > this.timeout);
}

AggregateCallback.prototype.update = function () {
	if (this._expired() && this.enforce)
		this.fire()
	
	if (this.timer) {
		clearTimeout(this.timer);
		this.timer = null;
	}
	
	var target = this;
	this.timer = setTimeout(function () { target.fire(); }, this.timeout);
}

function setupPreview(form) {
	console.log("setupPreview", form);
	
	var livePreview = new AggregateCallback(1000, true, function() {
		$.post("comments/preview", {'body': $('textarea[name=body]', form).val()}, function(data) {
			$('.preview', form).empty().append(data);
			$.syntax({context: $('.preview', form)});
		});
	});
	
	$('textarea[name=body]', form).keyup(function() {
		livePreview.update();
	});
	
	livePreview.update();
}

function setupComments(parent) {
	console.log("setupComments", parent);
	
	jQuery.syntax();
	
	var cookieOptions = {'path': '/', 'expires': 21};
	
	// Load default field values from local cookies.
	var commentsForm = $("#comments_form");
	var fields = ["name", "from", "website", "email"];
	
	for (var i in fields) {
		key = fields[i];
		var value = $.cookie(key);
		
		if (value) {
			$("input[name=" + key + "]", commentsForm).val(value);
		}
	}
	
	setupPreview(commentsForm);
	
	commentsForm.submit(function(evt) {
		evt.preventDefault();
		
		var submission = {
			'node': $('input[name=node]', commentsForm).val(),
			'body': $('textarea[name=body]', commentsForm).val()
		};
		
		for (var i in fields) {
			var value = $("input[name=" + fields[i] + "]", commentsForm).val();
			
			$.cookie(fields[i], value, cookieOptions);
			submission[fields[i]] = value;
		}
		
		// document.location.href
		$.post("comments/create", submission, function(comment) {
			commentsForm.xreload();
		});
	});
}

function deleteComment (button) {
	var id = $(button).parents('div.comment').data('id');
	
	if (confirm("Are you sure you want to delete this comment?")) {
		$.post('comments/delete', {'id': id}, function () {
			$(button).parents('div.comment').slideUp();
		});
	}
}

function moderateComment (button) {
	var id = $(button).parents('div.comment').data('id');
	
	$.post('comments/toggle', {'id': id}, function () {
		$(button).xreload();
	});
}

function editComment (button) {
	var id = $(button).parents('div.comment').data('id');
	
	var commentsForm = $('#comments_form').clone().attr('id', '');
	$(button).parents('div.comment').replaceWith(commentsForm);
	
	var fields = ["name", "from", "website", "email"];
	
	$.get('comments/edit', {'id': id}, function (comment) {
		for (var i in fields) {
			key = fields[i];
			var value = comment[key];

			if (value) {
				$("input[name=" + key + "]", commentsForm).val(value);
			}
		}
		
		$("input[value=" + comment.icon + "]", commentsForm).attr("checked", "checked");
		$('textarea[name=body]', commentsForm).val(comment.body);
		$('input[name=id]', commentsForm).val(comment.id);
	});
	
	$('input[type=submit]', commentsForm).val("Update Post");
	
	commentsForm.unbind('submit');
	
	setupPreview(commentsForm);
	
	commentsForm.submit(function(evt) {
		evt.preventDefault();
		
		var submission = {
			'node': $('input[name=node]', commentsForm).val(),
			'body': $('textarea[name=body]', commentsForm).val(),
			'id': $('input[name=id]', commentsForm).val()
		};
		
		for (var i in fields) {
			var value = $("input[name=" + fields[i] + "]", commentsForm).val();
			submission[fields[i]] = value;
		}
		
		$.post("comments/update", submission, function(comment) {
			$(commentsForm).xreload();
		});
	});
}
