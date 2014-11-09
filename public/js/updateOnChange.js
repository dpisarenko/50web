<script>
function api(method, url, params) {
	var request = new XMLHttpRequest();
	var data = new FormData();
	for (prop in params) {
		if (params.hasOwnProperty(prop)) {
			data.append(prop, params[prop]);
		}
	}
	request.open(method, url, true);
	request.send(data);
}

function sendUpdate() {
	var id = document.getElementById('personedit').getAttribute('data-id');
	return function(e) {
		var uri = 'PUT /api/peep/people/' + id;
		e.target.style.backgroundColor = '#c00';
		alert(uri + ' … ' + e.target.name + ' = ' + e.target.value);
		setTimeout(function() {
			e.target.style.backgroundColor = '#fff';
		}, 2000);
	};
}
document.getElementById('personedit').addEventListener('change', sendUpdate(), false);
</script>
