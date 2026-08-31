var socket, term;
var variant, first_task_text, diff;
var numA, numB, numAd, numAdOk, numBd, numBdOk, sum, sumOk, flagC, flagCOk, flagV, flagVOk;

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

const {token} = parseCookie(document.cookie);

window.addEventListener("load", () => {
	variant = document.getElementById("variant");
	first_task_text = document.getElementById("first_task_text");
	diff = document.getElementById("diff");

	numA   = document.getElementById("numA");
	numB   = document.getElementById("numB");
	numAd  = document.getElementById("numAd");
	numAdOk  = document.getElementById("numAdOk");
	numBd  = document.getElementById("numBd");
	numBdOk  = document.getElementById("numBdOk");
	sum    = document.getElementById("sum");
	sumOk    = document.getElementById("sumOk");
	flagC  = document.getElementById("flagC");
	flagCOk  = document.getElementById("flagCOk");
	flagV  = document.getElementById("flagV");
	flagVOk  = document.getElementById("flagVOk");

	term = new Terminal({cursorBlink: true, fontFamily: 'monospace'});
	term.open(document.getElementById('terminal'));

	socket = io.connect();
	socket.on('connect', () => {
		term.write('\r\n*** Connected to backend***\r\n');

		// Browser -> Backend
		term.onData((data) => {
			console.log(data);
			socket.emit('data', data);
		});

		// Backend -> Browser
		socket.on('data', (data) => {
			term.write(data);
		});

		socket.on('disconnect', function() {
			term.write('\r\n*** Disconnected from backend***\r\n');
		});

		socket.on('task', (data) => {
			first_task_text.innerText = data;
		});

		socket.on('diff', (data) => {
			diff.innerText = data;
		});

		socket.on('report_error', (data) => {
			console.log(`на сервере произошла ошибка: ${data}`);
			alert(`на сервере произошла ошибка: ${data}`);
		});
	});
});


const auth = () => {
	socket.emit("close");
	term.clear();
	socket.emit("auth", {token});
}

const logout = () => {
	socket.emit("logout", {
		token,
	});
	window.location.reload();
}


const unsigned2signed = (n) => {
	if (n < 32768)
		return n;
	return n - 65536;
}


const signed2unsigned = (n) => {
	if (n >= 0)
		return n;
	return 65536 + n;
}


const first_task = {
	generate: () => socket.emit("generate", {
		token,
		variant: variant.value
	}),

	check: () => socket.emit("check", {
		token,
		variant: variant.value
	})
};


const second_task = {
	generate: () => {
		numA.value = Math.floor(Math.random() * 65536) - 32768;
		numB.value = Math.floor(Math.random() * 65536) - 32768;
	},

	check: () => {
		const a = parseInt(numA.value, 10);
		const b = parseInt(numB.value, 10);

		const ua = signed2unsigned(a);
		const ub = signed2unsigned(b);

		const ad = parseInt(numAd.value, 16);
		const bd = parseInt(numBd.value, 16);

		const sumv = parseInt(sum.value, 16);
		const c = (ua + ub) > 65535;
		const pc = (ua & 32767) + (ub & 32767) > 32767;
		const v = c ^ pc;

		numAdOk.innerText = ua == ad ? 1 : 0;
		numBdOk.innerText = ub == bd ? 1 : 0;
		sumOk.innerText = (ua + ub) % 65536 == sumv ? 1 : 0;
		flagCOk.innerText = c == flagC.value ? 1 : 0;
		flagVOk.innerText = v == flagV.value ? 1 : 0;
	}
};
