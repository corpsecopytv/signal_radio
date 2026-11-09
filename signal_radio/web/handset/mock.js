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
	};

	send({ type: 'prefs', volume: 40 });
	pushState();
	send({ type: 'members', talkgroup: state.talkgroup, members });
	send({ type: 'open', open: true });
})();
