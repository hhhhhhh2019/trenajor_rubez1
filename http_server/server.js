const port = 8080; // порт, на котором будет запущен http сервер
const ssh_host = "localhost"; // хост на котором запущен ssh сервер
const ssh_port = 8022;
const generator_path = "/usr/sbin/generator";
const check_path = "/usr/sbin/check";

import { Client } from 'ssh2'
import { Server } from 'socket.io'
import { createServer } from 'http'
import { readFileSync } from 'fs'
import { URL } from 'url'
import { parse } from 'querystring'


const users = {};

const isUserValid = token => token in users;
const newToken = () => {
	while (true) {
		const token = Math.floor(Math.random() * 10000);

		if (isUserValid(token))
			continue;

		return token;
	}
}

const parseCookie = (str) => {
	const cookie = {};

	str.split(';').forEach(field => {
		let [name, ...value] = field.split('=');
		name = name?.trim();
		value = value.join('=').trim();
		if (name && value)
			cookie[name] = value;
	});

	return cookie;
}


const staticCache = {};

const readFile = (filename) => {
	// if (filename in staticCache)
	// 	return staticCache[filename];

	try {
		staticCache[filename] = readFileSync(filename);
	} catch {
		staticCache[filename] = null;
	}

	return staticCache[filename];
}


const getRoutingTable = {
	"/": (req, res) => {
		const cookie = req.headers.cookie ? parseCookie(req.headers.cookie) : {};
		if (isUserValid(cookie.token)) {
			res.writeHead(200, {
				"Content-Type": "text/html"
			});
			res.write(readFile("static/index.html"));
			res.end();
		} else {
			res.writeHead(200, {
				"Content-Type": "text/html"
			});
			res.write(readFile("static/login.html"));
			res.end();
		}
	},
	"/index.css": (req, res) => {
		res.writeHead(200, {
			"Content-Type": "text/css"
		});
		res.write(readFile("static/index.css"));
		res.end();
	},
	"/index.js": (req, res) => {
		res.writeHead(200, {
			"Content-Type": "text/javascript"
		});
		res.write(readFile("static/index.js"));
		res.end();
	},
	"/xterm.js": (req, res) => {
		res.writeHead(200, {
			"Content-Type": "text/javascript"
		});
		res.write(readFile("./node_modules/@xterm/xterm/lib/xterm.js"));
		res.end();
	},
	"/xterm.css": (req, res) => {
		res.writeHead(200, {
			"Content-Type": "text/css"
		});
		res.write(readFile("./node_modules/@xterm/xterm/css/xterm.css"));
		res.end();
	},
};


const server = createServer((req, res) => {
	const url = new URL(req.url, req.protocol + '://' + req.headers.host + '/');

	if (req.method == "GET") {
		if (url.pathname in getRoutingTable) {
			getRoutingTable[url.pathname](req, res);
		} else {
			res.writeHead(404);
			res.end("not found");
		}
	}

	else if (req.method == "POST" && url.pathname == "/login") {
		let body = "";
		req.on("data", (data) => {
			body += data.toString("utf-8");
		});
		req.on("end", () => {
			const {username, password} = parse(body);

			const conn = new Client();
			conn.on("ready", () => {
				const token = newToken();
				users[token] = {
					username,
					password,
				};
				res.setHeader('Set-Cookie', `token=${token}; Path=/`);
				res.setHeader('Location', '/');
				res.writeHead(301);
				res.end();

				conn.end();
			}).on("error", (err) => {
				console.log("login error:", err.message);
				res.writeHead(403);
				res.end("wrong username or password!");

				conn.end();
			}).connect({
				host: ssh_host,
				port: ssh_port,
				username,
				password
			});
		});
	}
});


const io = new Server(server);

io.on("connection", (socket) => {
	socket.on("generate", (params) => {
		const {token, variant} = params;
		// TODO: добавить провекри на то, что params это объект и у него есть нужные поля

		const conn = new Client();
		conn.on("ready", () => conn.exec(`${generator_path} "${variant}"`, (err, stream) => {
			if (err) {
				console.log("generate error:", err.message);
				socket.emit("report_error", err.message.toString("utf-8"));
				return;
			}

			stream
				.on("close", conn.end)
				.on("data", (data) => socket.emit("task", data.toString("utf-8")))
				.stderr.on("data", (data) => console.log("generate error:", data));
		})).on("error", (err) => {
			console.log("error:", err.message);
			socket.emit("report_error", err.message.toString("utf-8"));
		}).connect({
			host: ssh_host,
			port: ssh_port,
			username: users[token].username,
			password: users[token].password
		});
	});

	socket.on("check", (params) => {
		const {token, variant} = params;
		// TODO: добавить провекри на то, что params это объект и у него есть нужные поля

		const conn = new Client();
		conn.on("ready", () => conn.exec(`${check_path} /home/${users[token].username}/lab0 "${variant}"`, (err, stream) => {
			if (err) {
				console.log("check error:", err.message.toString("utf-8"));
				socket.emit("report_error", err.message.toString("utf-8"));
				return;
			}

			stream
				.on("close", conn.end)
				.on("data", (data) => socket.emit("diff", data.toString("utf-8")))
				.stderr.on("data", (data) => console.log("check error:", data.toString("utf-8")));
		})).on("error", (err) => {
			console.log("error:", err.message);
			socket.emit("report_error", err.message.toString("utf-8"));
		}).connect({
			host: ssh_host,
			port: ssh_port,
			username: users[token].username,
			password: users[token].password
		});
	});

	socket.on("logout", (params) => {
		const {token} = params;
		// TODO: добавить провекри на то, что params это объект и у него есть нужные поля

		delete users[token];
	});


	let curr_conn = null;

	socket.on("auth", (params) => {
		const {token} = params;
		// TODO нормально починить многопоточность

		if (curr_conn && curr_conn != 1) {
			curr_conn.end();
		}

		const conn = new Client();
		curr_conn = 1;

		conn.on("ready", () => conn.shell((err, stream) => {
			curr_conn = conn;

			if (err) {
				socket.emit("data", `\r\n*** SHELL ERROR: ${err.message}\r\n`);
				conn.end();
				curr_conn = null;
				return;
			}

			socket.on("data", (data) => stream.write(data));
			stream
				.on("data", (data) => socket.emit("data", data.toString("utf-8")))
				.on("close", () => {
					conn.end();
					curr_conn = null;
				});
		})).on("close", () =>
			socket.emit("data", "\r\n*** SHELL CLOSED ***\r\n")
		).on("error", (err) => {
			console.log("error:", err.message);
			socket.emit("data", `\r\n*** SHELL ERROR: ${err.message} ***\r\n`);
		}).connect({
			host: ssh_host,
			port: ssh_port,
			username: users[token].username,
			password: users[token].password
		});
	});

	socket.on("close", () => {
		if (curr_conn)
			curr_conn.end();
	});
});


server.listen(port, () => console.log(`listening on http://localhost:${port}`));
