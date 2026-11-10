'use strict';

/* Browser-only preview data. The game never loads this file. */
(() => {
	if (window.self === window.top) document.body.style.background = 'linear-gradient(160deg, #6f8796, #41515a)';

	const send = (data) => window.postMessage(data, '*');
	const previewSkin = new URLSearchParams(location.search).get('skin') || '';
	const zoneLabel = previewSkin.includes('fire') ? 'QFD' : 'QPS';
	const state = {
		available: true,
		power: true,
		talkgroup: 'qps_ops1',
		scanning: false,
		canScan: true,
		scanList: ['qps_ops1', 'qps_ops2', 'interop'],
		callsign: 'Bravo 12',
		tuning: false,
		frequency: 476425,
		bands: [[136000, 174000, 146000], [400000, 520000, 476425]],
		stepKHz: 25,
		priority: false,
		zones: [
			{ id: 'qps', label: zoneLabel, talkgroups: [
				{ id: 'qps_ops1', label: 'OPS 1' },
				{ id: 'qps_ops2', label: 'OPS 2' },
				{ id: 'qps_cmd', label: 'Command' },
			] },
			{ id: 'qas', label: 'QAS', talkgroups: [{ id: 'qas_ops', label: 'OPS' }] },
			{ id: 'qfd', label: 'QFD', talkgroups: [{ id: 'qfd_ops', label: 'OPS' }] },
			{ id: 'rfsq', label: 'RFSQ', talkgroups: [{ id: 'rfsq_ops', label: 'OPS' }] },
			{ id: 'interop', label: 'Interop', talkgroups: [{ id: 'interop', label: 'Interop' }] },
		],
	};
	if (previewSkin === 'uv5r') {
		Object.assign(state, {
			civilian: true,
			tuning: true,
			talkgroup: 'freq:476425',
			canScan: false,
			zones: [],
		});
	}
	const pushState = () => send({ type: 'state', state: { ...state }, self: 3 });
	const adminSnapshot = {
		self: 3,
		devTools: new URLSearchParams(location.search).get('dev') !== '0',
		bleedTest: false,
		devProfile: { department: 'qps', senior: false },
		shiftTarget: 3,
		towers: [
			{ id: 'legion', label: 'Legion Square', radius: 2500, online: true, sabotagedSeconds: 0, cooldownSeconds: 0 },
			{ id: 'paleto', label: 'Paleto Bay', radius: 3000, online: false, sabotagedSeconds: 212, cooldownSeconds: 1712 },
			{ id: 'sandy', label: 'Sandy Shores', radius: 3500, online: true, sabotagedSeconds: 0, cooldownSeconds: 640 },
		],
		players: [
			{ id: 3, name: 'Test Officer', hasRadio: true, callsign: 'Bravo 12', radio: 'QPS', power: true, channel: 'qps_ops1', channelNumber: 1001, signal: 'full' },
			{ id: 7, name: 'Second Client', hasRadio: true, callsign: 'Unit 7', radio: 'Civilian', power: true, channel: 'freq:462125', channelNumber: 462125, signal: 'worn' },
			{ id: 9, name: 'Radio Off', hasRadio: true, callsign: 'Charlie 4', radio: 'QFD', power: false, channelNumber: 0, signal: 'full' },
			{ id: 11, name: 'Just Joined', hasRadio: false },
		],
		nightShifts: {
			running: true,
			departments: [
				{ id: 1, name: 'Queensland Police Service', codeplug: 'qps' },
				{ id: 2, name: 'Queensland Ambulance Service', codeplug: 'qas' },
				{ id: 5, name: 'Tow', codeplug: null },
			],
			shift: { isOnShift: true, departmentId: 1, callsign: 'L-42', statusCode: 'available', location: { x: 215.4, y: -810.2, z: 30.7 } },
		},
	};
	const members = [
		{ id: 3, callsign: 'Bravo 12' },
		{ id: 7, callsign: 'Charlie 4' },
		{ id: 9, callsign: 'Sierra 21' },
	];

	window.mockRadio = {
		action(body) {
			if (body.action === 'power') state.power = body.on;
			if (body.action === 'selectTalkgroup') {
				state.talkgroup = body.talkgroup;
				state.tuning = false;
			}
			if (body.action === 'useFrequencyMode') {
				state.tuning = true;
				state.talkgroup = `freq:${state.frequency}`;
			}
			if (body.action === 'tune') {
				state.frequency = body.frequency;
				state.talkgroup = `freq:${body.frequency}`;
			}
			if (body.action === 'scan') state.scanning = body.enabled;
			if (body.action === 'setScanTalkgroup') {
				state.scanList = state.scanList.filter((id) => id !== body.talkgroup);
				if (body.enabled) state.scanList.push(body.talkgroup);
			}
			if (body.action === 'volume') send({ type: 'prefs', volume: body.value });
			if (body.action === 'ptt') send({ type: 'tx', active: body.down });
			if (body.action === 'panic') send({ type: 'panic', talkgroup: state.talkgroup, label: 'OPS 1', callsign: state.callsign });
			pushState();
			if (body.action === 'selectTalkgroup' || body.action === 'power') send({ type: 'members', talkgroup: state.talkgroup, members });
		},
		state,
		pushState,
		send,
		admin(body) {
			const a = adminSnapshot;
			if (body.action === 'close') return send({ type: 'adminOpen', open: false });
			if (body.action === 'refresh') return send({ type: 'adminSnapshot', snapshot: a });
			if (body.action === 'towerRadii') return send({ type: 'adminRadii', on: true });
			if (body.action === 'towerRemove') a.towers = a.towers.filter((tower) => tower.id !== body.id);
			if (body.action === 'towerClear') Object.assign(a.towers.find((tower) => tower.id === body.id), { online: true, sabotagedSeconds: 0, cooldownSeconds: 0 });
			if (body.action === 'towerRadius') a.towers.find((tower) => tower.id === body.id).radius = Number(body.radius);
			if (body.action === 'towerAdd') a.towers.push({ id: body.id, label: body.id, radius: Number(body.radius), online: true, sabotagedSeconds: 0, cooldownSeconds: 0 });
			if (body.action === 'setProfile') a.devProfile = body.department === 'off' ? null : { department: body.department, senior: body.senior };
			if (body.action === 'bleedTest') a.bleedTest = body.on;
			send({ type: 'adminNote', message: `Preview: ${body.action}` });
			send({ type: 'adminSnapshot', snapshot: a });
		},
	};

	send({ type: 'prefs', volume: 40 });
	pushState();
	send({ type: 'members', talkgroup: state.talkgroup, members });
	if (new URLSearchParams(location.search).has('admin')) {
		send({ type: 'adminSnapshot', snapshot: adminSnapshot });
		send({ type: 'adminOpen', open: true });
	} else {
		send({ type: 'open', open: true });
	}
})();
