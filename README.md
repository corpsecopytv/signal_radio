# signal_radio

Radio system for the Apex Network FiveM server, built on pma-voice.

The full design and build status are in [docs/plan.md](docs/plan.md). The voice proof, core radio, handsets and towers work in-game. Direct radio and speaker bleed are waiting on [docs/test_towers.md](docs/test_towers.md).

## Layout
- `signal_radio/` is the FiveM resource.
- `patches/signal_radio.patch` is the patch for pma-voice 7.0.1.
- `patches/signal_radio_upgrade_1.patch` updates a pma-voice that already has the earlier patch.
- `docs/test_core_radio.md` is the test script for the core radio and handsets.
- `docs/test_towers.md` is the test script for towers, signal, sabotage, the fireground channel, direct radio and speaker bleed.
- `docs/test_night_shifts.md` is the test script for Night Shifts MDT.
- `docs/test_admin_panel.md` is the test script for the admin panel.

pma-voice, Night Shifts MDT and `server.cfg` are never committed to this repo.

## Dev server setup
The radio reads shifts from Night Shifts MDT. Set your department IDs in `signal_radio/config/night_shifts.lua`. On a dev server, a test profile can stand in for a shift. This line adds the Test tools tab to the admin panel. Add it to the dev `server.cfg` only:

```
setr signal_radio_dev_tools 1
```

| Command or key | What it does |
| --- | --- |
| `/radioadmin` | Opens the admin panel. Needs the `radio.admin` ACE. |
| F6 or `/radio` | Opens or puts away the handset. The key can be changed in FiveM settings. |
| Left Alt | Talks on the radio, as set by pma-voice. |
| `/callsign <name>` | Sets your callsign when you are off shift. On shift, the MDT sets it. |
