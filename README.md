# signal_radio

Radio system for the Apex Network FiveM server, built on pma-voice.

The full design and build status are in [docs/plan.md](docs/plan.md). The voice proof, core radio, handsets and towers work in-game. Direct radio and speaker bleed are waiting on [docs/test_towers.md](docs/test_towers.md).

## Layout
- `signal_radio/` is the FiveM resource.
- `patches/signal_radio.patch` is the patch for pma-voice 7.0.1.
- `patches/signal_radio_upgrade_1.patch` updates a pma-voice that already has the earlier patch.
- `docs/voice_proof.md` is the step 1 test script.
- `docs/test_core_radio.md` is the test script for the core radio and handsets.
- `docs/test_towers.md` is the test script for towers, signal, sabotage, the fireground channel, direct radio and speaker bleed.
- `docs/test_night_shifts.md` is the test script for Night Shifts MDT.

pma-voice, Night Shifts MDT and `server.cfg` are never committed to this repo.

## Dev server setup
The radio reads shifts from Night Shifts MDT. Set your department IDs in `signal_radio/config/night_shifts.lua`. On a dev server, a dev profile can stand in for a shift. Add this to the dev `server.cfg` only:

```
setr signal_radio_dev_profiles 1
```

| Command or key | What it does |
| --- | --- |
| `/radio_dev <qps, qas, qfd, rfsq, off> [senior]` | Sets your dev department. `off` gives you the civilian radio. `senior` adds the command channel. Needs the `radio.admin` ACE. |
| F6 or `/radio` | Opens or puts away the handset. The key can be changed in FiveM settings. |
| Left Alt | Talks on the radio, as set by pma-voice. |
| `/callsign <name>` | Sets your callsign when you are off shift. On shift, the MDT sets it. |
| `radio_ns_dump [server id]` | Prints the Night Shifts departments and one player's shift to the server console. Needs the server console or the `radio.admin` ACE. |
| `/radio_tower <add, remove, radius, clear, list>` | Manages towers. Needs the `radio.admin` ACE. |
| `/radio_tower_debug` | Shows or hides each tower's radius on the map. |
