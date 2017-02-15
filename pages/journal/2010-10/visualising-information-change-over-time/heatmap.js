
jQuery(function(){
	$('.heatmap').each(function() {
		var paths = $('ul.paths li', this).slice(1);
		var data = $('ul.data li', this).slice(1);
		
		paths.each(function(i) {
			var row = data.eq(i);
			
			$(this).bind('mouseover', function() {
				$(this).addClass('hover');
				row.addClass('hover');
			});
			
			$(this).bind('mouseout', function() {
				$(this).removeClass('hover');
				row.removeClass('hover');
			});
		});

		data.each(function(i) {
			var row = paths.eq(i);
			
			$(this).bind('mouseover', function() {
				$(this).addClass('hover');
				row.addClass('hover');
			});
			
			$(this).bind('mouseout', function() {
				$(this).removeClass('hover');
				row.removeClass('hover');
			});
		});
	});
	// 
	// tipsy_options = {
	// 	gravity: function() {
	// 		return $(this).offset().left > ($(document).scrollLeft() + $(window).width() / 2) ? 'ne' : 'nw';
	//     },
	// 	delayIn: 100,
	// };
	// 
	// $('a.temperature', this).tipsy(tipsy_options);
	// $('a.date', this).tipsy(tipsy_options);
	// 
	// $('.data', this).dragscrollable({
	// 	dragSelector: '>*'
	// });
});
