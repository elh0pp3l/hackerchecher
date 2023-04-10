function hackclear(){
	document.getElementById('response_container').innerHTML = '';
}

function hackcheck(){
	hackclear();
	hackrequestData();
}
function hackconnect() {
	
		ws = new WebSocket(host);

    ws.onopen = function() {
        console.log('Socket open.');             
    };
    
	ws.onmessage = function(event) {
		var obj = JSON.parse(event.data);
		if (obj.errors){
			document.getElementById('response_container').innerHTML = '<div class="alert alert-primary" role="alert">'+obj.errors[0]+'</div>';
			return;
		}
		var html='<table class="table table-striped table-bordered" id="sortTable"><thead><tr><th>platoon</th><th>name</th><th>id</th><th>latency</th><th>hacker</th><th>Check</th></tr></thead><tbody>';
		
		
		if (obj.teams){
			html += obj.serverinfo.country + '<br>';
			html += obj.serverinfo.level + '<br>';
			html += obj.serverinfo.mode + '<br>';
			html += obj.serverinfo.name + '<br>';
			html += obj.serverinfo.region + '<br>';
			html += obj.serverinfo.servertype + '<br><hr>';
			obj.teams.forEach(function(o) {
				html += '<tr><td colspan=6>' + o.name + '</td></tr>';
				if (o.players){
					o.players.forEach(function(p){
						var bfv_url = 'https://bfvhackers.com/?name=' + encodeURI(p.name);
						if (p.hacker === false){
							
							html += '<tr><td>' + p.platoon +'</td><td>'+p.name+'</td><td>'+p.player_id+'</td><td>'+p.latency+'</td><td>'+p.hacker+'</td><td><a target="_blank" href="'+bfv_url+'">'+bfv_url+'</a></td></tr>';
						}
						else {
							html += '<tr class="table-danger"><td>' + p.platoon +'</td><td>'+p.name+'</td><td>'+p.player_id+'</td><td>'+p.latency+'</td><td>'+p.hacker+'</td><td><a target="_blank" href="'+bfv_url+'">'+bfv_url+'</a></td></tr>';							
						}

					});
				}
			});
		}
		
		html += '</tbody></table>';
		document.getElementById('response_container').innerHTML = html;

    };
    
    ws.onclose = function(event) {
        console.log('Socket is closed. Reconnect will be attempted in 5 seconds.', event.reason);
        setTimeout(function(){ hackconnect();}, 5000)        
    };
    
    ws.onerror = function(err){
        console.error('Socket encountered error: ', err.message, 'Closing socket')
        ws.close()
    };

}
async function hackrequestData() {
    //     <div class="spinner-border" role="status"><span class="sr-only">Loading...</span></div>
    const msg = {
		server: document.getElementById("bfvserver").value
	};
    ws.send(JSON.stringify(msg));
}
