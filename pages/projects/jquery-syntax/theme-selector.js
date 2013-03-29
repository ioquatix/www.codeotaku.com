
jQuery.fn.removeClasses = function(pattern) {
	this.each(function() {
		var classes = this.className.split(/\s+/);
		
		for (var i = 0; i < classes.length; i++) {
			if (classes[i].match(pattern)) {
				classes[i] = null;
			}
		}
		
		this.className = classes.join(' ');
	});
	
	return this;
}

jQuery(function($) {
	var div = $('#jquery-theme-selector');
	var select = $('<select>');
	
	for (var key in Syntax.themes) {
		if (key == 'base')
			continue;
		
		var option = $('<option>' + key + '</option>');
		option.attr('value', key);
		
		if (key == 'paper')
			option.attr('selected', true);
		
		select.append(option);
	}
	
	select.bind('change', function(event) {
		var classes = [];
		var theme = Syntax.themes[select.val()];
		theme.push(select.val());
		
		for (var i = 0; i < theme.length; i += 1) {
			classes.push('syntax-theme-' + theme[i]);
		}
		
		$('.syntax-container').removeClasses(/syntax-theme-.*/).addClass(classes.join(' '));
	});
	
	div.append(select);
});