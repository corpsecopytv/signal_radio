# signal_radio

Radio system for the Apex Network FiveM server, built on pma-voice.

The full design and build status are in [docs/plan.md](docs/plan.md). Step 1, the voice proof, is done. The core radio and handsets are built and ready for in-game testing with [docs/test_core_radio.md](docs/test_core_radio.md).

## Layout
- `signal_radio/` is the FiveM resource.
- `patches/signal_radio.patch` is the patch for pma-voice 7.0.1.
- `docs/voice_proof.md` is the step 1 test script.
- `docs/test_core_radio.md` is the test script for the core radio and handsets.
- `docs/test_towers.md` is the test script for towers, signal, sabotage, the fireground channel, direct radio and speaker bleed.

pma-voice, Night Shifts MDT and `server.cfg` are never committed to this repo.

## Dev server setup
Night Shifts is not connected yet, so a dev profile stands in for a shift. Add this to the dev `server.cfg` only:

```
setr signal_radio_dev_profiles 1
```

| Command or key | What it does |
| --- | --- |
| `/radio_dev <qps, qas, qfd, rfsq, off> [senior]` | Sets your dev department. `off` gives you the civilian radio. `senior` adds the command channel. Needs the `radio.admin` ACE. |
| F6 or `/radio` | Opens or puts away the handset. The key can be changed in FiveM settings. |
| Left Alt | Talks on the radio, as set by pma-voice. |
| `/callsign <name>` | Sets your callsign. |
| `/radio_tower <add, remove, radius, clear, list>` | Manages towers. Needs the `radio.admin` ACE. |
| `/radio_tower_debug` | Shows or hides each tower's radius on the map. |
