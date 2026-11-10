'use strict';

/* Player names and MDT data are untrusted. They only ever reach the page as text nodes. */
(() => {
	const inGame = typeof GetParentResourceName === 'function';
	const REFRESH_MS = 5000;
	const CONFIRM_MS = 4000;

	const panel = {
		open: false,
		tab: 'radios',
		snapshot: null,
		shiftTarget: null,
		confirmRemove: null,
		confirmTimer: null,
		refreshTimer: null,
		radiiOn: false,
	};

	const root = document.createElement('section');
	root.id = 'admin';
	root.className = 'admin';
	root.hidden = true;
	root.setAttribute('role', 'dialog');
	root.setAttribute('aria-label', 'Radio admin');
	root.innerHTML = `
		<div class="admin-window">
			<header class="admin-head">
				<h1>Radio admin</h1>
				<div class="admin-readout" aria-live="off">
					<span id="adminRadiosOn"></span>
					<span id="adminTowersUp"></span>
					<span id="adminMdtState"></span>
				</div>
				<button id="adminClose" class="admin-btn" type="button">Close</button>
			</header>

			<div class="admin-body">
				<nav class="admin-tabs" role="tablist" aria-label="Admin sections">
					<button type="button" role="tab" data-tab="radios">Radios</button>
					<button type="button" role="tab" data-tab="towers">Towers</button>
					<button type="button" role="tab" data-tab="nightShifts">Night Shifts</button>
					<button type="button" role="tab" data-tab="test" id="adminTestTab" hidden>Test tools</button>
				</nav>

				<div class="admin-pane" data-pane="radios">
					<table class="admin-table">
						<thead><tr><th>ID</th><th>Player</th><th>Callsign</th><th>Radio</th><th>Channel</th><th>Number</th><th>Signal</th></tr></thead>
						<tbody id="adminRadios"></tbody>
					</table>
				</div>

				<div class="admin-pane" data-pane="towers" hidden>
					<form id="adminTowerAdd" class="admin-row">
						<label>Tower ID<input id="adminTowerId" maxlength="32" autocomplete="off" required></label>
						<label>Radius in metres<input id="adminTowerNewRadius" type="number" min="1" step="any" value="2500" required></label>
						<button class="admin-btn admin-btn-main" type="submit">Add at my position</button>
						<button id="adminRadii" class="admin-btn admin-push" type="button">Show radius on map</button>
					</form>
					<table class="admin-table">
						<thead><tr><th>Tower</th><th>Status</th><th>Radius</th><th></th></tr></thead>
						<tbody id="adminTowers"></tbody>
					</table>
				</div>

				<div class="admin-pane" data-pane="nightShifts" hidden>
					<p id="adminMdtNote" class="admin-note"></p>
					<div id="adminMdtDetail">
						<h2>Departments</h2>
						<p class="admin-note">Radios are mapped by ID in config/night_shifts.lua.</p>
						<table class="admin-table">
							<thead><tr><th>ID</th><th>Department</th><th>Radio</th></tr></thead>
							<tbody id="adminDepartments"></tbody>
						</table>
						<h2>Shift data</h2>
						<label class="admin-inline">Player<select id="adminShiftPlayer"></select></label>
						<dl id="adminShift" class="admin-fields"></dl>
					</div>
				</div>

				<div class="admin-pane admin-tools" data-pane="test" hidden>
					<fieldset>
						<legend>My test profile</legend>
						<div class="admin-row" id="adminProfiles">
							<button class="admin-btn" type="button" data-department="qps">QPS</button>
							<button class="admin-btn" type="button" data-department="qas">QAS</button>
							<button class="admin-btn" type="button" data-department="qfd">QFD</button>
							<button class="admin-btn" type="button" data-department="rfsq">RFSQ</button>
							<button class="admin-btn" type="button" data-department="off">None</button>
						</div>
						<label class="admin-check"><input id="adminSenior" type="checkbox">Senior, with the command channel</label>
					</fieldset>

					<fieldset>
						<legend>Timed transmit</legend>
						<form id="adminTransmit" class="admin-row">
							<label>Seconds<input id="adminTxSeconds" type="number" min="1" max="60" value="10"></label>
							<label>Start after<input id="adminTxDelay" type="number" min="0" max="30" value="5"></label>
							<button class="admin-btn admin-btn-main" type="submit">Start</button>
						</form>
					</fieldset>

					<fieldset>
						<legend>Move me</legend>
						<form id="adminGoTo" class="admin-row">
							<label>X<input id="adminX" type="number" step="any" required></label>
							<label>Y<input id="adminY" type="number" step="any" required></label>
							<label>Z<input id="adminZ" type="number" step="any" placeholder="60"></label>
							<button class="admin-btn admin-btn-main" type="submit">Go and freeze</button>
						</form>
						<div class="admin-row">
							<button class="admin-btn" type="button" data-spot="a">Spot A</button>
							<button class="admin-btn" type="button" data-spot="b">Spot B</button>
							<button class="admin-btn" type="button" data-spot="c">Spot C</button>
							<button id="adminRelease" class="admin-btn admin-push" type="button">Release</button>
						</div>
					</fieldset>

					<fieldset>
						<legend>Speaker bleed</legend>
						<div class="admin-row">
							<button id="adminBleedOn" class="admin-btn" type="button">Place test radio here</button>
							<button id="adminBleedOff" class="admin-btn" type="button">Remove test radio</button>
						</div>
					</fieldset>

					<fieldset>
						<legend>Watch a talker's voice</legend>
						<form id="adminWatch" class="admin-row">
							<label>Server ID<input id="adminWatchId" type="number" min="1" required></label>
							<button class="admin-btn admin-btn-main" type="submit">Watch</button>
							<button id="adminWatchStop" class="admin-btn" type="button">Stop</button>
						</form>
					</fieldset>
				</div>
			</div>

			<footer id="adminFoot" class="admin-foot" role="status"></footer>
		</div>`;
	document.body.append(root);

	const byId = (id) => document.getElementById(id);
	const tabs = [...root.querySelectorAll('[role="tab"]')];
	const panes = [...root.querySelectorAll('[data-pane]')];

	function send(action, data = {}) {
		const body = { action, ...data };
		if (!inGame) {
			if (window.mockRadio) window.mockRadio.admin(body);
			return;
		}
		fetch(`https://${GetParentResourceName()}/admin`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json; charset=UTF-8' },
			body: JSON.stringify(body),
		}).catch(() => {});
	}

	function el(tag, className, text) {
		const node = document.createElement(tag);
		if (className) node.className = className;
		if (text !== undefined && text !== null) node.textContent = String(text);
		return node;
	}

	function button(label, onClick, className = '') {
		const node = el('button', `admin-btn ${className}`.trim(), label);
		node.type = 'button';
		node.onclick = onClick;
		return node;
	}

	function row(...cells) {
		const tr = el('tr');
		for (const cell of cells) {
			if (cell instanceof Node) tr.append(cell);
			else tr.append(el('td', '', cell));
		}
		return tr;
	}

	function emptyRow(tbody, columns, text) {
		const td = el('td', 'admin-empty', text);
		td.colSpan = columns;
		const tr = el('tr');
		tr.append(td);
		tbody.replaceChildren(tr);
	}

	const clock = (seconds) => `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;

	function channelText(channel) {
		if (!channel) return 'No channel';
		if (channel.startsWith('freq:')) return (Number(channel.slice(5)) / 1000).toFixed(3);
		return channel;
	}

	function isEditing(container) {
		return container.contains(document.activeElement) && document.activeElement.matches('input, select');
	}

	function renderReadout(snapshot) {
		const on = snapshot.players.filter((player) => player.power).length;
		const up = snapshot.towers.filter((tower) => tower.online).length;
		byId('adminRadiosOn').textContent = `${on} of ${snapshot.players.length} radios on`;
		byId('adminTowersUp').textContent = `${up} of ${snapshot.towers.length} towers up`;
		byId('adminMdtState').textContent = snapshot.nightShifts.running ? 'MDT running' : 'MDT stopped';
	}

	function renderRadios(snapshot) {
		const tbody = byId('adminRadios');
		if (!snapshot.players.length) return emptyRow(tbody, 7, 'No players are online.');
		tbody.replaceChildren(...snapshot.players.map((player) => {
			if (!player.hasRadio) return row(player.id, player.name, 'No radio yet', '', '', '', '');
			return row(
				player.id,
				player.name,
				player.callsign,
				player.radio,
				player.power ? channelText(player.channel) : 'Off',
				player.power && player.channelNumber ? player.channelNumber : '',
				player.power ? player.signal : '',
			);
		}));
	}

	function towerStatusCell(tower) {
		const td = el('td');
		td.append(el('div', tower.online ? 'admin-up' : 'admin-down', tower.online ? 'Online' : `Offline for ${clock(tower.sabotagedSeconds)}`));
		if (tower.cooldownSeconds > 0) td.append(el('div', 'admin-sub', `Cooldown ${clock(tower.cooldownSeconds)}`));
		return td;
	}

	function towerRadiusCell(tower) {
		const td = el('td');
		const form = el('form', 'admin-row admin-tight');
		const input = el('input');
		input.type = 'number';
		input.min = '1';
		input.step = 'any';
		input.required = true;
		input.value = tower.radius;
		input.setAttribute('aria-label', `Radius of ${tower.label}`);
		const set = el('button', 'admin-btn', 'Set');
		set.type = 'submit';
		form.append(input, set);
		form.onsubmit = (event) => {
			event.preventDefault();
			send('towerRadius', { id: tower.id, radius: Number(input.value) });
		};
		td.append(form);
		return td;
	}

	function towerActionsCell(tower, snapshot) {
		const td = el('td');
		const actions = el('div', 'admin-row admin-tight admin-end');
		if (snapshot.devTools) actions.append(button('Stand beside', () => send('goToTower', { id: tower.id })));
		const clear = button('Clear sabotage', () => send('towerClear', { id: tower.id }));
		clear.disabled = tower.online && tower.cooldownSeconds === 0;
		actions.append(clear);
		const confirming = panel.confirmRemove === tower.id;
		actions.append(button(confirming ? 'Confirm remove' : 'Remove', () => {
			clearTimeout(panel.confirmTimer);
			if (confirming) {
				panel.confirmRemove = null;
				send('towerRemove', { id: tower.id });
				return;
			}
			panel.confirmRemove = tower.id;
			panel.confirmTimer = setTimeout(() => {
				panel.confirmRemove = null;
				renderTowers(panel.snapshot);
			}, CONFIRM_MS);
			renderTowers(panel.snapshot);
		}, confirming ? 'admin-btn-danger' : ''));
		td.append(actions);
		return td;
	}

	function renderTowers(snapshot) {
		const tbody = byId('adminTowers');
		if (isEditing(tbody)) return;
		if (!snapshot.towers.length) return emptyRow(tbody, 4, 'No towers are set. Stand at a site and add one.');
		tbody.replaceChildren(...snapshot.towers.map((tower) => {
			const name = el('td');
			name.append(el('div', '', tower.label));
			if (tower.label !== tower.id) name.append(el('div', 'admin-sub', tower.id));
			return row(name, towerStatusCell(tower), towerRadiusCell(tower), towerActionsCell(tower, snapshot));
		}));
	}

	function renderNightShifts(snapshot) {
		const info = snapshot.nightShifts;
		byId('adminMdtNote').textContent = info.running ? '' : 'Night Shifts is not running. Players get a civilian radio unless they have a test profile.';
		byId('adminMdtNote').hidden = info.running;
		byId('adminMdtDetail').hidden = !info.running;
		if (!info.running) return;

		const departments = byId('adminDepartments');
		if (!info.departments.length) {
			emptyRow(departments, 3, 'Night Shifts has no departments yet.');
		} else {
			departments.replaceChildren(...info.departments.map((department) => row(
				department.id,
				department.name,
				department.codeplug ? department.codeplug.toUpperCase() : 'Civilian radio, not mapped',
			)));
		}

		const select = byId('adminShiftPlayer');
		if (!isEditing(select.parentElement)) {
			panel.shiftTarget = snapshot.shiftTarget;
			select.replaceChildren(...snapshot.players.map((player) => {
				const option = el('option', '', `${player.id}: ${player.name}`);
				option.value = player.id;
				return option;
			}));
			select.value = snapshot.shiftTarget;
		}

		const fields = byId('adminShift');
		const entries = Object.entries(info.shift || {}).sort(([a], [b]) => a.localeCompare(b));
		if (!entries.length) {
			fields.replaceChildren(el('dd', 'admin-empty', 'Night Shifts returned no shift data.'));
			return;
		}
		fields.replaceChildren(...entries.flatMap(([key, value]) => [
			el('dt', '', key),
			el('dd', '', typeof value === 'object' ? JSON.stringify(value) : value),
		]));
	}

	function renderTools(snapshot) {
		const active = snapshot.devProfile ? snapshot.devProfile.department : 'off';
		for (const node of byId('adminProfiles').querySelectorAll('[data-department]')) {
			node.classList.toggle('admin-btn-on', node.dataset.department === active);
		}
		byId('adminSenior').checked = Boolean(snapshot.devProfile && snapshot.devProfile.senior);
		byId('adminBleedOn').classList.toggle('admin-btn-on', snapshot.bleedTest);
		byId('adminBleedOff').disabled = !snapshot.bleedTest;
	}

	function showTab(tab) {
		panel.tab = tab;
		for (const node of tabs) node.setAttribute('aria-selected', String(node.dataset.tab === tab));
		for (const pane of panes) pane.hidden = pane.dataset.pane !== tab;
	}

	function render() {
		const snapshot = panel.snapshot;
		if (!snapshot) return;
		byId('adminTestTab').hidden = !snapshot.devTools;
		if (panel.tab === 'test' && !snapshot.devTools) showTab('radios');
		renderReadout(snapshot);
		renderRadios(snapshot);
		renderTowers(snapshot);
		renderNightShifts(snapshot);
		renderTools(snapshot);
	}

	function setOpen(open) {
		panel.open = open;
		root.hidden = !open;
		clearInterval(panel.refreshTimer);
		if (open) {
			panel.refreshTimer = setInterval(() => send('refresh', { shiftTarget: panel.shiftTarget }), REFRESH_MS);
		} else {
			clearTimeout(panel.confirmTimer);
			panel.confirmRemove = null;
		}
	}

	function showNote(message, failed) {
		const foot = byId('adminFoot');
		foot.textContent = message;
		foot.classList.toggle('admin-foot-failed', Boolean(failed));
	}

	window.addEventListener('message', (event) => {
		const data = event.data || {};
		if (data.type === 'adminOpen') setOpen(data.open);
		if (data.type === 'adminSnapshot') {
			panel.snapshot = data.snapshot;
			render();
		}
		if (data.type === 'adminNote') showNote(data.message, data.failed);
		if (data.type === 'adminRadii') {
			panel.radiiOn = data.on;
			byId('adminRadii').textContent = data.on ? 'Hide radius on map' : 'Show radius on map';
		}
	});

	window.addEventListener('keydown', (event) => {
		if (event.key === 'Escape' && panel.open) send('close');
	});

	const onSubmit = (id, handler) => {
		byId(id).onsubmit = (event) => {
			event.preventDefault();
			handler();
		};
	};
	const setProfile = (department) => send('setProfile', { department, senior: byId('adminSenior').checked });

	for (const node of tabs) node.onclick = () => showTab(node.dataset.tab);
	byId('adminClose').onclick = () => send('close');
	byId('adminRadii').onclick = () => send('towerRadii');
	byId('adminShiftPlayer').onchange = (event) => {
		panel.shiftTarget = Number(event.target.value);
		event.target.blur();
		send('refresh', { shiftTarget: panel.shiftTarget });
	};
	onSubmit('adminTowerAdd', () => {
		send('towerAdd', { id: byId('adminTowerId').value.trim(), radius: Number(byId('adminTowerNewRadius').value) });
		byId('adminTowerId').value = '';
	});
	for (const node of byId('adminProfiles').querySelectorAll('[data-department]')) {
		node.onclick = () => setProfile(node.dataset.department);
	}
	byId('adminSenior').onchange = () => {
		const profile = panel.snapshot && panel.snapshot.devProfile;
		if (profile) setProfile(profile.department);
	};
	onSubmit('adminTransmit', () => send('transmit', { seconds: Number(byId('adminTxSeconds').value), delay: Number(byId('adminTxDelay').value) }));
	onSubmit('adminGoTo', () => send('goTo', {
		x: Number(byId('adminX').value),
		y: Number(byId('adminY').value),
		z: byId('adminZ').value === '' ? undefined : Number(byId('adminZ').value),
	}));
	for (const node of root.querySelectorAll('[data-spot]')) node.onclick = () => send('goToSpot', { spot: node.dataset.spot });
	byId('adminRelease').onclick = () => send('release');
	byId('adminBleedOn').onclick = () => send('bleedTest', { on: true });
	byId('adminBleedOff').onclick = () => send('bleedTest', { on: false });
	onSubmit('adminWatch', () => send('watch', { talker: Number(byId('adminWatchId').value) }));
	byId('adminWatchStop').onclick = () => send('watch');

	showTab('radios');
})();
