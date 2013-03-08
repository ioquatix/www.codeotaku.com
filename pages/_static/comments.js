
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

$(function() {
	var cookieOptions = {'path': '/', 'expires': 21};
	
	// Load default field values from local cookies.
	var commentsForm = $("#comments_form");
	var fields = ["posted_by", "from", "website", "email"];
	
	for (var i in fields) {
		key = fields[i];
		var value = $.cookie(key);
		
		if (value) {
			$("input[name=" + key + "]", commentsForm).val(value);
		}
	}
	
	var currentIcon = $.cookie("icon");
	if (currentIcon) {
		$("input[value=" + currentIcon + "]").attr("checked", "checked");
	}
	
	// Setup icon selector
	var checkIconFunction = null;
	
	$('.icons span').each(function() {
		var button = $('input[name=icon]', this);
		var icon = $('img', this);
		
		var updateIconFunction = function() {
			if (button.is(':checked')) {
				$('.icons img.selected').removeClass('selected');
				icon.addClass('selected');
			}
		};
		
		if (checkIconFunction == null || button.is(":checked")) {
			checkIconFunction = function() {
				button.attr("checked", "checked");
				updateIconFunction();
				current = button;
			}
		}
		
		button.change(updateIconFunction);
		button.bind('propertychange', updateIconFunction);
		button.hide();
	});

	if (checkIconFunction)
		checkIconFunction();
	
	$("#comments_form").validate({
		rules: {
			posted_by: "required",
			email: {
				required: true,
				email: true
			},
			website: {
				url: true
			},
			body: "required"
		}
	});

	var livePreview = new AggregateCallback(1000, true, function() {
		$.post("comments/preview", {'body': $('textarea[name=body]', commentsForm).val()}, function(data) {
			$('.preview', commentsForm).empty().append(data);
			$.syntax({context: $('.preview', commentsForm)});
		});
	});
	
	$('textarea[name=body]', commentsForm).keyup(function() {
		livePreview.update();
	});
	
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

		var currentIcon = $("input[name=icon]:checked", commentsForm).each(function() {
			$.cookie("icon", this.value, cookieOptions);
			submission["icon"] = this.value;
		});
		
		// document.location.href
		$.post("comments/create", submission, function(comment) {
			//var commentHTML = $('<div class="xframe" src="/blog/comment?id=' + comment.id + '" />');
			//commentHTML.insertBefore(commentsForm);
			//commentHTML.xreload();
			commentsForm.xreload();
			//$('textarea[name=body]', commentsForm).val('');
		});
	});
});

function deleteComment (button, id) {
	if (confirm("Are you sure you want to delete this comment?")) {
		$.post('comments/delete', {'id': id}, function () {
			$(button).parents('div.comment').slideUp();
		});
	}
}

function moderateComment (button, id) {
	$.post('comments/toggle', {'id': id}, function () {
		$(button).xreload();
	});
}

function editComment (button, id) {
	var commentsForm = $('#comments_form').clone().attr('id', '');
	$(button).parents('div.comment').replaceWith(commentsForm);
	
	var fields = ["posted_by", "from", "website", "email"];
	
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

		var currentIcon = $("input[name=icon]:checked", commentsForm).each(function() {
			submission["icon"] = this.value;
		});
		
		$.post("comments/update", submission, function(comment) {
			$(button).xreload();
		});
	});
}
