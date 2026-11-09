'use strict';

const inGame = typeof GetParentResourceName === 'function';
const $ = (id) => document.getElementById(id);
const HOLD_EMERGENCY_MS = 700;

const app = {
	open: false,
	self: 0,
	state: { available: false },
	view: 'main',
	memberLists: {},
	talkers: new Map(),
	tx: false,
	volume: 30,
	entry: '',
	encrypted: false,
	encryptedTraffic: false,
	bars: 4,
	message: null,
	messageTimer: null,
	alert: null,
	alertTimer: null,
};

function post(action, data = {}) {
	const body = { action, ...data };
	if (!inGame) {
		if (window.mockRadio) window.mockRadio.action(body);
		return;
	}
	fetch(`https://${GetParentResourceName()}/action`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json; charset=UTF-8' },
		body: JSON.stringify(body),
	}).catch(() => {});
}

/* Tones are generated here, so the handset ships no audio files. */
let audioContext;
function tone(steps, level = 0.1) {
	audioContext = audioContext || new AudioContext();
	let at = audioContext.currentTime;
	for (const [frequency, duration] of steps) {
		if (frequency > 0) {
			const oscillator = audioContext.createOscillator();
			const gain = audioContext.createGain();
			oscillator.type = 'square';
			oscillator.frequency.value = frequency;
			gain.gain.value = level;
			oscillator.connect(gain).connect(audioContext.destination);
			oscillator.start(at);
			oscillator.stop(at + duration);
		}
		at += duration;
	}
}
const tones = {
	grant: () => tone([[1320, 0.05], [0, 0.02], [1760, 0.06]]),
	release: () => tone([[880, 0.05]], 0.05),
	busy: () => tone([[420, 0.09], [0, 0.05], [420, 0.09], [0, 0.05], [420, 0.09]]),
	power: () => tone([[660, 0.07], [990, 0.09]]),
	receive: () => tone([[1500, 0.03]], 0.04),
	panic: () => tone(Array.from({ length: 8 }, (_, i) => [i % 2 ? 680 : 940, 0.14]), 0.14),
};

/* Looping band-limited noise for encrypted traffic. */
let noiseSource;
function setEncrypted(active) {
	app.encrypted = active;
	if (noiseSource) {
		noiseSource.stop();
		noiseSource = null;
	}
	if (!active) return;
	audioContext = audioContext || new AudioContext();
	const samples = audioContext.sampleRate;
	const buffer = audioContext.createBuffer(1, samples, samples);
	const channel = buffer.getChannelData(0);
	for (let i = 0; i < samples; i += 1) channel[i] = Math.random() * 2 - 1;
	noiseSource = audioContext.createBufferSource();
	noiseSource.buffer = buffer;
	noiseSource.loop = true;
	const filter = audioContext.createBiquadFilter();
	filter.type = 'bandpass';
	filter.frequency.value = 1700;
	filter.Q.value = 0.8;
	const gain = audioContext.createGain();
	gain.gain.value = 0.08;
	noiseSource.connect(filter).connect(gain).connect(audioContext.destination);
	noiseSource.start();
}

function formatFrequency(kilohertz) {
	const digits = String(kilohertz).padStart(6, '0');
	return `${digits.slice(0, 3)}.${digits.slice(3)}`;
}

function formatEntry(entry) {
	const digits = entry.padEnd(6, '_');
	return `${digits.slice(0, 3)}.${digits.slice(3)}`;
}

function bandLabel(kilohertz) {
	return kilohertz >= 300000 ? 'UHF' : 'VHF';
}

function tuneTo(kilohertz) {
	const inBand = (app.state.bands || []).some(([low, high]) => kilohertz >= low && kilohertz <= high);
	if (!inBand) {
		showMessage(`${formatFrequency(kilohertz)} is out of band.`);
		return;
	}
	post('tune', { frequency: kilohertz });
}

function pressDigit(digit) {
	if (!app.state.power) return;
	if (!app.state.tuning) {
		if (digit > 0) window.radioHandset.selectChannel(digit);
		return;
	}
	app.view = 'main';
	app.entry += String(digit);
	if (app.entry.length === 6) {
		const frequency = Number(app.entry);
		app.entry = '';
		tuneTo(frequency);
	}
	render();
}

function removeLastDigit() {
	app.entry = app.entry.slice(0, -1);
	render();
}

function talkgroupIndex() {
	const entries = new Map();
	for (const zone of app.state.zones || []) {
		for (const talkgroup of zone.talkgroups) entries.set(talkgroup.id, { ...talkgroup, zone });
	}
	return entries;
}

function currentZoneTalkgroups() {
	const current = talkgroupIndex().get(app.state.talkgroup);
	return current ? current.zone.talkgroups : [];
}

function activeReceive() {
	const others = [...app.talkers.entries()].filter(([key]) => !key.endsWith(`:${app.self}`));
	if (others.length === 0) return null;
	const primary = others.find(([key]) => key.startsWith(`${app.state.talkgroup}:`));
	const [key, callsign] = primary || others[0];
	return { callsign, talkgroup: key.slice(0, key.lastIndexOf(':')) };
}

function radioMode() {
	if (!app.state.available || !app.state.power) return 'off';
	if (app.alert) return 'alert';
	if (app.tx) return 'tx';
	return activeReceive() || app.encrypted ? 'rx' : 'idle';
}

function showMessage(text, milliseconds = 1800) {
	clearTimeout(app.messageTimer);
	app.message = text;
	app.messageTimer = setTimeout(() => {
		app.message = null;
		render();
	}, milliseconds);
	render();
}

function statusLine(index) {
	if (app.tx) return 'Transmitting';
	if (app.state.tuning) {
		if (app.encrypted) return 'ENC';
		return activeReceive() ? 'Receiving' : '';
	}
	const receive = activeReceive();
	if (receive) {
		const scanned = receive.talkgroup !== app.state.talkgroup;
		const label = scanned && index.get(receive.talkgroup) ? ` on ${index.get(receive.talkgroup).label}` : '';
		return `${receive.callsign}${label}`;
	}
	return app.state.callsign || '';
}

function fitChannelLabel() {
	const label = $('channel');
	let size = parseFloat(getComputedStyle(label).getPropertyValue('--channel-size'));
	label.style.fontSize = `${size}px`;
	while (label.scrollWidth > label.clientWidth && size > 14) {
		size -= 2;
		label.style.fontSize = `${size}px`;
	}
}

function setSoftkeys(keys) {
	keys.forEach((key, position) => {
		const number = position + 1;
		const button = $(`soft${number}`);
		$(`softLabel${number}`).textContent = key ? key.label : '';
		button.setAttribute('aria-label', key ? key.label : 'Unused key');
		button.disabled = !key || key.disabled === true;
		button.onclick = key && key.run ? key.run : null;
	});
}

function renderList() {
	const list = $('list');
	list.replaceChildren();
	if (app.view === 'units') {
		const place = app.state.tuning ? 'frequency' : 'channel';
		const members = app.memberLists[app.state.talkgroup] || [];
		$('listTitle').textContent = `Units on this ${place}`;
		const others = members.filter((member) => member.id !== app.self);
		for (const member of members) {
			const row = document.createElement('div');
			row.className = 'lcd-row';
			row.textContent = member.id === app.self ? `${member.callsign} (you)` : member.callsign;
			list.append(row);
		}
		if (others.length === 0) {
			const empty = document.createElement('p');
			empty.textContent = `Nobody else is on this ${place}.`;
			list.append(empty);
		}
		return;
	}

	if (app.view === 'scan') {
		$('listTitle').textContent = 'Scan list';
		const addRow = (label, checked, onclick) => {
			const row = document.createElement('button');
			row.type = 'button';
			row.className = `lcd-row${checked ? ' is-checked' : ''}`;
			row.textContent = label;
			row.onclick = onclick;
			list.append(row);
		};
		addRow(`Scan: ${app.state.scanning ? 'on' : 'off'}`, false, () => post('scan', { enabled: !app.state.scanning }));
		const chosen = new Set(app.state.scanList || []);
		for (const zone of app.state.zones || []) {
			for (const talkgroup of zone.talkgroups) {
				const label = zone.label === talkgroup.label ? zone.label : `${zone.label} ${talkgroup.label}`;
				addRow(label, chosen.has(talkgroup.id), () => post('setScanTalkgroup', { talkgroup: talkgroup.id, enabled: !chosen.has(talkgroup.id) }));
			}
		}
		return;
	}

	if (app.state.civilian) {
		$('listTitle').textContent = 'Choose a band';
		for (const [low, high, start] of app.state.bands || []) {
			const row = document.createElement('button');
			row.type = 'button';
			const tunedHere = app.state.frequency >= low && app.state.frequency <= high;
			row.className = `lcd-row${tunedHere ? ' is-current' : ''}`;
			row.textContent = bandLabel(start);
			row.onclick = () => {
				tuneTo(start);
				app.view = 'main';
				render();
			};
			list.append(row);
		}
		return;
	}

	$('listTitle').textContent = 'Choose a zone';
	const current = app.state.tuning ? null : talkgroupIndex().get(app.state.talkgroup);
	const frequencyRow = document.createElement('button');
	frequencyRow.type = 'button';
	frequencyRow.className = `lcd-row${app.state.tuning ? ' is-current' : ''}`;
	frequencyRow.textContent = 'Frequency';
	frequencyRow.onclick = () => {
		post('useFrequencyMode');
		app.view = 'main';
		render();
	};
	list.append(frequencyRow);
	for (const zone of app.state.zones || []) {
		if (zone.talkgroups.length === 0) continue;
		const row = document.createElement('button');
		row.type = 'button';
		row.className = `lcd-row${current && current.zone.id === zone.id ? ' is-current' : ''}`;
		row.textContent = zone.label;
		row.onclick = () => {
			post('selectTalkgroup', { talkgroup: zone.talkgroups[0].id });
			app.view = 'main';
			render();
		};
		list.append(row);
	}
}

function listRows() {
	return [...$('list').querySelectorAll('.lcd-row')];
}

function applyListCursor() {
	const list = $('list');
	const rows = listRows();
	if (rows.length === 0) return;
	if (app.listCursorView !== app.view) {
		app.listCursorView = app.view;
		app.listCursor = Math.max(0, rows.findIndex((row) => row.classList.contains('is-current')));
	}
	app.listCursor = Math.min(app.listCursor, rows.length - 1);
	const row = rows[app.listCursor];
	row.classList.add('is-cursor');
	const top = row.offsetTop - list.offsetTop;
	if (top < list.scrollTop) list.scrollTop = top;
	else if (top + row.offsetHeight > list.scrollTop + list.clientHeight) list.scrollTop = top + row.offsetHeight - list.clientHeight;
}

/** @returns {boolean} true when a list is open and took the key press */
function moveListCursor(direction) {
	if (app.view === 'main') return false;
	const count = listRows().length;
	if (count > 0) {
		app.listCursor = (app.listCursor + direction + count) % count;
		render();
	}
	return true;
}

function selectListRow() {
	const row = listRows()[app.listCursor];
	if (row && row.tagName === 'BUTTON') row.click();
}

function render() {
	const { state } = app;
	const mode = radioMode();
	const index = talkgroupIndex();
	const current = index.get(state.talkgroup);
	const on = state.available && state.power;

	$('handset').hidden = !app.open;
	$('lcd').dataset.mode = !state.available ? 'idle' : mode;
	$('lcd').toggleAttribute('data-tuning', Boolean(state.tuning));
	$('led').dataset.led = mode === 'off' || mode === 'idle' ? 'off' : mode;
	$('power').setAttribute('aria-pressed', on ? 'true' : 'false');
	$('power').disabled = !state.available;

	const canOperate = Boolean(on);
	for (const id of ['channelKnob', 'channelPrev', 'channelNext', 'volumeDown', 'volumeUp', 'panic', 'ptt']) {
		$(id).disabled = !canOperate;
	}

	const listing = on && app.view !== 'main';
	$('viewMain').hidden = listing;
	$('viewList').hidden = !listing;
	if (listing) {
		renderList();
		applyListCursor();
	} else {
		app.listCursorView = null;
	}

	if (!state.available) {
		$('zone').textContent = '';
		$('channel').textContent = '';
		$('status').textContent = '';
	} else {
		$('zone').textContent = state.tuning ? bandLabel(state.frequency) : (current ? current.zone.label : '');
		const tuned = app.entry ? formatEntry(app.entry) : formatFrequency(state.frequency);
		$('channel').textContent = state.tuning ? tuned : (current ? current.label : '');
		$('status').textContent = statusLine(index);
	}
	const statusInHeader = state.tuning && (app.tx || app.encrypted || activeReceive());
	const showDirect = on && app.bars === 0 && !statusInHeader;
	$('directFlag').hidden = !showDirect;
	/* The square screen has room for one tag, and Direct matters more. */
	const roomForScan = !showDirect || $('lcd').dataset.layout !== 'square';
	$('scanFlag').hidden = !(on && state.scanning && !state.tuning && roomForScan);
	if (app.open && !listing) fitChannelLabel();

	const message = $('message');
	message.hidden = true;
	message.replaceChildren();
	if (!state.available) {
		message.hidden = false;
		message.textContent = 'Start a shift in the MDT to use your radio.';
	} else if (app.alert && on) {
		message.hidden = false;
		const title = document.createElement('strong');
		title.textContent = 'Emergency';
		message.append(title, `${app.alert.callsign} on ${app.alert.label}`);
	} else if (app.message && on) {
		message.hidden = false;
		message.textContent = app.message;
	}

	if (!on) {
		setSoftkeys([null, null, null]);
	} else if (state.civilian) {
		const backLabel = app.view !== 'main' ? 'Back' : (app.entry ? 'Clear' : null);
		setSoftkeys([
			app.view === 'zones' ? { label: 'Select', run: selectListRow } : null,
			null,
			backLabel ? { label: backLabel, run: window.radioHandset.showMain } : null,
		]);
	} else if (app.view === 'main' && state.tuning) {
		setSoftkeys([
			null,
			{ label: 'Units', run: () => { app.view = 'units'; render(); } },
			app.entry
				? { label: 'Clear', run: window.radioHandset.showMain }
				: { label: 'Zone', run: () => { app.view = 'zones'; render(); } },
		]);
	} else if (app.view === 'main') {
		setSoftkeys([
			{ label: 'Scan', disabled: !state.canScan, run: () => { app.view = 'scan'; render(); } },
			{ label: 'Units', run: () => { app.view = 'units'; render(); } },
			{ label: 'Zone', run: () => { app.view = 'zones'; render(); } },
		]);
	} else {
		setSoftkeys([
			null,
			app.view === 'zones' || app.view === 'scan' ? { label: 'Select', run: selectListRow } : null,
			{ label: 'Back', run: () => { app.view = 'main'; render(); } },
		]);
	}

	const strip = $('strip');
	strip.hidden = app.open || !on;
	if (!strip.hidden) {
		strip.dataset.mode = mode;
		$('stripChannel').textContent = state.tuning ? formatFrequency(state.frequency) : (current ? `${current.zone.label} ${current.label}` : '');
		$('stripStatus').textContent = app.alert ? `Emergency: ${app.alert.callsign}` : (app.tx || app.encrypted || activeReceive() ? statusLine(index) : '');
	}
}

function stepChannel(direction) {
	if (app.state.tuning) {
		app.entry = '';
		tuneTo(app.state.frequency + direction * (app.state.stepKHz || 25));
		render();
		return;
	}
	const talkgroups = currentZoneTalkgroups();
	if (talkgroups.length < 2) return;
	const position = talkgroups.findIndex((talkgroup) => talkgroup.id === app.state.talkgroup);
	const next = talkgroups[(position + direction + talkgroups.length) % talkgroups.length];
	post('selectTalkgroup', { talkgroup: next.id });
}

function stepVolume(direction) {
	const value = Math.max(0, Math.min(100, app.volume + direction * 10));
	post('volume', { value });
	showMessage(`Volume ${value}`, 900);
}

function applyPosition(x, y) {
	const box = $('handset');
	const scale = parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--scale')) || 1;
	const maxX = Math.max(0, window.innerWidth - box.offsetWidth * scale);
	const maxY = Math.max(0, window.innerHeight - box.offsetHeight * scale);
	app.x = Math.max(0, Math.min(maxX, x));
	app.y = Math.max(0, Math.min(maxY, y));
	box.style.left = `${app.x}px`;
	box.style.top = `${app.y}px`;
}

function placeHandset() {
	const box = $('handset');
	const wasHidden = box.hidden;
	box.hidden = false;
	const scale = Math.min(1, (window.innerHeight - 24) / box.offsetHeight);
	document.documentElement.style.setProperty('--scale', String(scale));
	if (app.saved) applyPosition(app.saved.x, app.saved.y);
	else applyPosition(window.innerWidth - box.offsetWidth * scale - 28, window.innerHeight - box.offsetHeight * scale - 16);
	box.hidden = wasHidden;
}

const handlers = {
	open(data) {
		app.open = data.open;
		if (!data.open) app.view = 'main';
		if (data.open) placeHandset();
		render();
	},
	prefs(data) {
		if (data.volume !== undefined) app.volume = data.volume;
		if (data.position) app.saved = data.position;
	},
	state(data) {
		const before = app.state;
		app.state = data.state;
		app.self = data.self;
		if (app.state.skin) window.radioSkin.use(app.state.skin);
		if (before.power !== app.state.power && app.state.available) {
			if (app.state.power) tones.power();
			app.talkers.clear();
			app.tx = false;
		}
		if (before.talkgroup !== app.state.talkgroup) app.talkers.clear();
		if (!app.state.power) { app.view = 'main'; app.entry = ''; }
		if (!app.state.power || before.frequency !== app.state.frequency || before.tuning !== app.state.tuning) {
			app.encryptedTraffic = false;
			setEncrypted(false);
		}
		if (!app.state.tuning) app.entry = '';
		render();
	},
	members(data) {
		/* The server can send this before the state that names the new channel, so keep every list. */
		app.memberLists[data.talkgroup] = data.members;
		render();
	},
	talk(data) {
		const key = `${data.talkgroup}:${data.talker}`;
		if (data.talking) {
			if (data.talker !== app.self && !app.talkers.has(key)) tones.receive();
			app.talkers.set(key, data.callsign);
		} else {
			app.talkers.delete(key);
		}
		render();
	},
	tx(data) {
		if (data.active && !app.tx) tones.grant();
		if (!data.active && app.tx) tones.release();
		app.tx = data.active;
		render();
	},
	encrypted(data) {
		app.encryptedTraffic = data.active === true;
		setEncrypted(app.encryptedTraffic && app.bars > 0);
		render();
	},
	signal(data) {
		app.bars = data.bars;
		document.querySelector('.bars').dataset.level = String(data.bars);
		setEncrypted(app.encryptedTraffic && app.bars > 0);
		render();
	},
	towerStatus(data) {
		showMessage(`${data.label} tower ${data.online ? 'back online' : 'offline'}`, 3500);
	},
	denied() {
		tones.busy();
		showMessage('Channel busy');
	},
	panic(data) {
		tones.panic();
		app.alert = data;
		clearTimeout(app.alertTimer);
		app.alertTimer = setTimeout(() => { app.alert = null; render(); }, 8000);
		render();
	},
	panicRefused() {
		showMessage('Wait before sending another emergency.');
	},
};

window.addEventListener('message', (event) => {
	const handler = handlers[event.data && event.data.type];
	if (handler) handler(event.data);
});

$('power').onclick = () => post('power', { on: !app.state.power });
$('power').onwheel = (event) => { if (app.state.power) stepVolume(event.deltaY > 0 ? -1 : 1); };
$('channelKnob').onclick = () => stepChannel(1);
$('channelKnob').onwheel = (event) => stepChannel(event.deltaY > 0 ? 1 : -1);
/* Radios without separate up and down keys use their channel keys for lists. */
function channelKey(listDirection, channelDirection) {
	if (app.view === 'main') stepChannel(channelDirection);
	else if ($('volumeUp').hidden) moveListCursor(listDirection);
}
$('channelPrev').onclick = () => channelKey(1, -1);
$('channelNext').onclick = () => channelKey(-1, 1);
$('volumeDown').onclick = () => { if (!moveListCursor(1)) stepVolume(-1); };
$('volumeUp').onclick = () => { if (!moveListCursor(-1)) stepVolume(1); };
$('close').onclick = () => post('close');

/* The emergency button needs a deliberate hold with a pointer. Keyboard activation is immediate. */
let holdTimer, holdFrame;
function clearHold() {
	clearTimeout(holdTimer);
	cancelAnimationFrame(holdFrame);
	$('panic').style.setProperty('--hold', '0%');
}
$('panic').onpointerdown = () => {
	const started = performance.now();
	const animate = (now) => {
		$('panic').style.setProperty('--hold', `${Math.min(100, ((now - started) / HOLD_EMERGENCY_MS) * 100)}%`);
		holdFrame = requestAnimationFrame(animate);
	};
	holdFrame = requestAnimationFrame(animate);
	holdTimer = setTimeout(() => {
		clearHold();
		post('panic');
	}, HOLD_EMERGENCY_MS);
};
$('panic').onpointerup = clearHold;
$('panic').onpointerleave = clearHold;
$('panic').onclick = (event) => { if (event.detail === 0) post('panic'); };

let pttDown = false;
function setPtt(down) {
	if (down === pttDown) return;
	pttDown = down;
	$('ptt').classList.toggle('is-down', down);
	post('ptt', { down });
}
$('ptt').onpointerdown = () => setPtt(true);
window.addEventListener('pointerup', () => setPtt(false));
window.addEventListener('blur', () => setPtt(false));

let dragging = null;
$('grip').onpointerdown = (event) => {
	dragging = { dx: event.clientX - app.x, dy: event.clientY - app.y };
	$('grip').setPointerCapture(event.pointerId);
};
$('grip').onpointermove = (event) => {
	if (dragging) applyPosition(event.clientX - dragging.dx, event.clientY - dragging.dy);
};
$('grip').onpointerup = () => {
	if (!dragging) return;
	dragging = null;
	app.saved = { x: app.x, y: app.y };
	post('savePosition', app.saved);
};

window.addEventListener('keydown', (event) => {
	if (event.key === 'Escape' && app.open) post('close');
	if (app.open && event.key === 'ArrowUp' && moveListCursor(-1)) event.preventDefault();
	if (app.open && event.key === 'ArrowDown' && moveListCursor(1)) event.preventDefault();
	if (app.open && event.key === 'Enter' && (app.view === 'zones' || app.view === 'scan')) {
		event.preventDefault();
		selectListRow();
	}
	if (app.open && /^[0-9]$/.test(event.key)) pressDigit(Number(event.key));
	if (app.open && event.key === 'Backspace' && app.state.tuning) removeLastDigit();
});
window.addEventListener('resize', () => { if (app.open) placeHandset(); });

window.radioHandset = {
	pressDigit,
	removeLastDigit,
	openUnits() {
		if (!app.state.power) return;
		if (app.view === 'zones') {
			selectListRow();
			return;
		}
		app.entry = '';
		app.view = 'units';
		render();
	},
	openZones() {
		if (!app.state.power) return;
		app.entry = '';
		app.view = 'zones';
		render();
	},
	showMain() {
		app.view = 'main';
		app.entry = '';
		render();
	},
	selectChannel(number) {
		if (!app.state.power) return;
		const talkgroup = currentZoneTalkgroups()[number - 1];
		if (talkgroup) post('selectTalkgroup', { talkgroup: talkgroup.id });
		else showMessage(`No channel ${number} in this zone.`);
	},
};

window.addEventListener('skinready', () => {
	if (app.open) placeHandset();
	render();
});

if (inGame) {
	post('ready');
} else {
	const script = document.createElement('script');
	script.src = 'mock.js';
	document.body.append(script);
}
render();
