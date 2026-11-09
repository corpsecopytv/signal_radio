'use strict';

/*
 * Photo handsets. Each skin's coordinates are [x, y, width, height] in pixels of its original photo.
 * image is the radio area of that photo, starting at imageOrigin and enlarged by the AI upscaler.
 * reference is the original width of that area. A different photo needs new coordinates.
 * If an image is missing, the handset keeps its built-in maroon body.
 */
(() => {
	const DEFAULT_SKIN = 'apx2000';

	const skins = {
		apx2000: {
			image: 'skins/apx2000_hd.png',
			imageOrigin: [10, 330],
			reference: 220,
			crop: [14, 335, 212, 450],
			displayWidth: 300,
			backgroundLevel: 226,
			antennaCap: { centerX: 159.5, centerY: 362, radiusX: 20.5, radiusY: 22, left: 136, right: 184 },
			screen: [71.25, 570, 98.75, 54],
			lcdLayout: 'wide',
			led: [177, 451],
			hotspots: {
				power: [34, 366, 47, 46],
				channelKnob: [90, 337, 32, 58],
				panic: [118, 408, 34, 15],
				ptt: [22, 468, 16, 100],
				grip: [60, 440, 128, 108],
				soft1: [71, 645, 29.5, 13],
				soft2: [106, 645, 30.5, 13],
				soft3: [141.5, 645, 28.5, 13],
				channelPrev: [96, 670, 15, 17],
				channelNext: [130, 670, 15, 17],
				volumeUp: [111, 663, 19, 12.5],
				volumeDown: [111, 681, 19, 12.5],
			},
			home: [71.5, 663, 21, 31],
			putAway: [149, 663, 21, 31],
			keypad: { area: [71, 698.5, 99, 49.5], columns: 3, rows: 3 },
			zeroKey: [105.5, 752, 30, 13],
			backspaceKey: [71, 752, 29, 13],
		},
		apx8000xe_fire: {
			image: 'skins/apx8000xe_fire_hd.png',
			imageOrigin: [10, 355],
			reference: 220,
			crop: [18, 360, 204, 436],
			displayWidth: 300,
			backgroundLevel: 130,
			antennaCap: { centerX: 56.25, centerY: 392, radiusX: 16.5, radiusY: 21, left: 36, right: 76 },
			screen: [82.5, 525.75, 72, 72.25],
			lcdLayout: 'square',
			led: [90.5, 500],
			hotspots: {
				power: [168, 402, 49, 41],
				channelKnob: [98, 366, 41, 58],
				panic: [58, 426, 34, 10],
				ptt: [40, 528, 15, 138],
				grip: [78, 478, 80, 42],
				soft1: [81, 613, 22, 14],
				soft2: [108, 613, 21.5, 14],
				soft3: [134, 613, 21.5, 14],
				channelPrev: [97, 644, 13, 13],
				channelNext: [127, 644, 13, 13],
				volumeUp: [111, 634, 16, 11],
				volumeDown: [111, 656, 16, 11],
			},
			home: [76, 634, 15, 33],
			putAway: [146, 634, 15, 33],
			keypad: { area: [76, 675.5, 85, 59], columns: 3, rows: 3 },
			zeroKey: [106, 734.5, 25, 13.5],
			backspaceKey: [76, 734.5, 24.5, 13.5],
		},
		/* The UV-5R has one knob, no D-pad and no emergency button, so it has no panic zone. */
		uv5r: {
			image: 'skins/uv5r.webp',
			imageOrigin: [0, 0],
			reference: 425,
			crop: [0, 130, 420, 815],
			displayWidth: 300,
			backgroundLevel: 226,
			antennaCap: { centerX: 116, centerY: 190, radiusX: 49, radiusY: 58, left: 60, right: 172 },
			screen: [82.5, 306.5, 256.5, 95],
			lcdLayout: 'strip',
			ledBox: [70, 542.5, 25, 27.5],
			hotspots: {
				power: [262, 173, 116, 68],
				ptt: [4, 436, 42, 140],
				grip: [150, 455, 210, 175],
				channelPrev: [219, 708, 60, 36],
				channelNext: [141, 708, 63, 36],
			},
			menuKey: [66, 708, 63, 36],
			bandKey: [313, 646, 50, 34],
			exitKey: [291, 708, 66, 36],
			keypad: { area: [66, 754, 226, 143], columns: 3, rows: 3 },
			zeroKey: [291, 801.5, 66, 36],
			backspaceKey: [291, 753, 66, 36],
		},
	};

	function loadImage(source) {
		return new Promise((resolve) => {
			const image = new Image();
			image.onload = () => resolve(image);
			image.onerror = () => resolve(null);
			image.src = source;
		});
	}

	/* Makes the photo's background transparent and keeps only the radio. */
	function cutOut(context, width, height, cap, backgroundLevel) {
		const picture = context.getImageData(0, 0, width, height);
		const data = picture.data;
		const total = width * height;
		const background = new Uint8Array(total);
		const isLight = (p) => Math.min(data[p * 4], data[p * 4 + 1], data[p * 4 + 2]) > backgroundLevel;
		const neighbours = (p) => {
			const list = [];
			if (p % width > 0) list.push(p - 1);
			if (p % width < width - 1) list.push(p + 1);
			if (p >= width) list.push(p - width);
			if (p < total - width) list.push(p + width);
			return list;
		};

		const stack = [];
		const seed = (p) => {
			if (!background[p] && isLight(p)) {
				background[p] = 1;
				stack.push(p);
			}
		};
		for (let x = 0; x < width; x += 1) { seed(x); seed(total - width + x); }
		for (let y = 0; y < height; y += 1) { seed(y * width); seed(y * width + width - 1); }
		while (stack.length) {
			for (const n of neighbours(stack.pop())) seed(n);
		}

		const visited = new Uint8Array(total);
		let largest = [];
		for (let start = 0; start < total; start += 1) {
			if (background[start] || visited[start]) continue;
			const part = [start];
			visited[start] = 1;
			for (let i = 0; i < part.length; i += 1) {
				for (const n of neighbours(part[i])) {
					if (!background[n] && !visited[n]) {
						visited[n] = 1;
						part.push(n);
					}
				}
			}
			if (part.length > largest.length) largest = part;
		}
		const keep = new Uint8Array(total);
		for (const p of largest) keep[p] = 1;

		for (let p = 0; p < total; p += 1) {
			if (!keep[p]) {
				data[p * 4 + 3] = 0;
				continue;
			}
			const row = Math.floor(p / width);
			const column = p % width;
			if (column >= cap.left && column < cap.right && row < cap.centerY) {
				const offset = (column - cap.centerX) / cap.radiusX;
				const edge = Math.abs(offset) < 1 ? cap.centerY - cap.radiusY * Math.sqrt(1 - offset * offset) : cap.centerY;
				data[p * 4 + 3] *= Math.max(0, Math.min(1, (row - edge) / 1.5));
			}
		}
		context.putImageData(picture, 0, 0);
	}

	function renderArt(skin, image) {
		const unit = image.naturalWidth / skin.reference;
		const [cropX, cropY, cropW, cropH] = skin.crop;
		const [originX, originY] = skin.imageOrigin;
		const scale = skin.displayWidth / cropW;
		const canvas = document.createElement('canvas');
		canvas.className = 'skin-art';
		canvas.width = skin.displayWidth;
		canvas.height = Math.round(cropH * scale);
		canvas.style.height = `${cropH * scale}px`;
		const context = canvas.getContext('2d', { willReadFrequently: true });
		context.fillStyle = '#fff';
		context.fillRect(0, 0, canvas.width, canvas.height);
		context.imageSmoothingEnabled = true;
		context.imageSmoothingQuality = 'high';
		context.drawImage(image, (cropX - originX) * unit, (cropY - originY) * unit, cropW * unit, cropH * unit, 0, 0, canvas.width, canvas.height);
		const cap = skin.antennaCap;
		cutOut(context, canvas.width, canvas.height, {
			centerX: (cap.centerX - cropX) * scale,
			centerY: (cap.centerY - cropY) * scale,
			radiusX: cap.radiusX * scale,
			radiusY: cap.radiusY * scale,
			left: (cap.left - cropX) * scale,
			right: (cap.right - cropX) * scale,
		}, skin.backgroundLevel);
		return canvas;
	}

	function addHotspot(handset, place, area, label, onclick) {
		const button = document.createElement('button');
		button.type = 'button';
		button.className = 'hotspot';
		button.title = label;
		button.setAttribute('aria-label', label);
		button.onclick = onclick;
		place(button, area);
		handset.append(button);
	}

	function apply(skin, canvas) {
		const handset = document.getElementById('handset');
		const [cropX, cropY, cropW, cropH] = skin.crop;
		const scale = skin.displayWidth / cropW;
		const place = (element, [x, y, width, height]) => {
			element.style.left = `${(x - cropX) * scale}px`;
			element.style.top = `${(y - cropY) * scale}px`;
			element.style.width = `${width * scale}px`;
			element.style.height = `${height * scale}px`;
		};

		handset.querySelectorAll('.skin-art, .hotspot').forEach((element) => element.remove());
		handset.classList.add('skinned');
		handset.style.width = `${skin.displayWidth}px`;
		handset.style.height = `${cropH * scale + 30}px`;
		handset.prepend(canvas);

		const lcd = document.getElementById('lcd');
		lcd.dataset.layout = skin.lcdLayout;
		place(lcd, skin.screen);

		const mapped = new Set(Object.keys(skin.hotspots));
		for (const button of handset.querySelectorAll('button[id], #grip')) {
			button.hidden = button.id !== 'close' && !mapped.has(button.id);
		}
		for (const [id, area] of Object.entries(skin.hotspots)) {
			place(document.getElementById(id), area);
		}

		const [gripX, gripY] = skin.hotspots.grip;
		const led = document.getElementById('led');
		if (skin.ledBox) {
			const [boxX, boxY, boxWidth, boxHeight] = skin.ledBox;
			led.dataset.shape = 'square';
			led.style.left = `${(boxX - gripX) * scale}px`;
			led.style.top = `${(boxY - gripY) * scale}px`;
			led.style.width = `${boxWidth * scale}px`;
			led.style.height = `${boxHeight * scale}px`;
		} else {
			delete led.dataset.shape;
			led.style.left = `${(skin.led[0] - gripX) * scale - 4}px`;
			led.style.top = `${(skin.led[1] - gripY) * scale - 4}px`;
			led.style.width = '';
			led.style.height = '';
		}

		if (skin.home) addHotspot(handset, place, skin.home, 'Back to the channel screen', () => window.radioHandset.showMain());
		if (skin.putAway) addHotspot(handset, place, skin.putAway, 'Put radio away', () => document.getElementById('close').click());
		if (skin.menuKey) addHotspot(handset, place, skin.menuKey, 'Open units', () => window.radioHandset.openUnits());
		if (skin.bandKey) addHotspot(handset, place, skin.bandKey, 'Choose a band', () => window.radioHandset.openZones());
		if (skin.exitKey) addHotspot(handset, place, skin.exitKey, 'Back to the channel screen', () => window.radioHandset.showMain());

		const { area, columns, rows } = skin.keypad;
		const cellWidth = area[2] / columns;
		const cellHeight = area[3] / rows;
		for (let digit = 1; digit <= columns * rows; digit += 1) {
			const column = (digit - 1) % columns;
			const row = Math.floor((digit - 1) / columns);
			addHotspot(handset, place, [area[0] + column * cellWidth, area[1] + row * cellHeight, cellWidth, cellHeight],
				`Key ${digit}`, () => window.radioHandset.pressDigit(digit));
		}
		if (skin.zeroKey) addHotspot(handset, place, skin.zeroKey, 'Key 0', () => window.radioHandset.pressDigit(0));
		if (skin.backspaceKey) addHotspot(handset, place, skin.backspaceKey, 'Delete last digit', () => window.radioHandset.removeLastDigit());

		window.dispatchEvent(new Event('skinready'));
	}

	const rendered = {};
	let requested = null;

	async function use(name) {
		const chosen = skins[name] ? name : DEFAULT_SKIN;
		if (requested === chosen) return;
		requested = chosen;
		if (!rendered[chosen]) {
			const image = await loadImage(skins[chosen].image);
			if (!image) return;
			rendered[chosen] = renderArt(skins[chosen], image);
		}
		if (requested === chosen) apply(skins[chosen], rendered[chosen]);
	}

	window.radioSkin = { use };
	const preview = typeof GetParentResourceName === 'function' ? null : new URLSearchParams(location.search).get('skin');
	use(preview || DEFAULT_SKIN);
})();
