var net = require('net');

var server = net.createServer(function (socket) {
	socket.on('data', function(data){
		socket.write(data.toString())
	})
});

server.listen(9090, "localhost");
