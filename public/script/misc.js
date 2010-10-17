$(function(){
	$('#forks').mousedown(function(){
		if ($('#forks').hasClass('clicked')) {
			$('#forks').removeClass('clicked');
			$('#forks-pane').hide();
		} else {
			$('#forks').addClass('clicked');
			$('#forks-pane').show();
		}			
		return false;
	});
});
