# Test procedure: admin panel

One person runs this on one PC, with two FiveM clients, on the dev server. Client 1 is A. Client 2 is B. Allow about 15 minutes.

## What this run does not cover
- The Night Shifts tab with real data. `docs/test_night_shifts.md` covers it.
- A player with no `radio.admin`, unless you do the optional part of test 1.

## Setup
1. Replace `setr signal_radio_dev_profiles 1` and `setr signal_radio_voice_proof 1` in the dev `server.cfg` with one line:

```
setr signal_radio_dev_tools 1
```

2. Keep the `add_ace` line for `radio.admin`.
3. Restart the server. The resource has new files.
4. Start both clients in windowed mode, side by side.

Pass: the server console shows no `signal_radio` errors.

## Test 1: Open and close
1. On A, type `/radioadmin`.
2. Press Esc.
3. Press F6 to open the radio, put it away, and type `/radioadmin` again.
4. Press Close.

Pass:
- The panel opens with the mouse active.
- The game takes no key presses while the panel is open.
- Esc and Close both close it, and you can move again.

Optional: remove the `add_ace` line, restart the server and type `/radioadmin`. Pass: nothing opens, chat says you need the radio.admin permission, and the server console shows an `add_ace` line with your license. Put the line back.

## Test 2: Old commands are gone
On A, type each of these: `/radio_dev qps`, `/radio_tower list`, `/radio_tower_debug`, `/vp_goto 0 0`, `/radio_ns_dump`.

Pass: none of them does anything.

## Test 3: Radios tab
1. On A, open the panel and go to Test tools. Press QPS.
2. On B, open the radio and turn it on.
3. On A, go to the Radios tab and wait 5 seconds.

Pass: both players are listed with their server IDs. A shows QPS. B shows Civilian, on 476.425, with its channel number.

## Test 4: Towers tab
1. Press Stand beside on legion. Open the panel again.
2. Type `paneltest` and `800`, and press Add at my position.
3. Press Show radius on map. Close the panel and open the pause map.
4. Open the panel again and set paneltest's radius to `400`.
5. Press Remove on paneltest. Wait 5 seconds without pressing again.
6. Press Remove, then Confirm remove.

Pass:
- Stand beside puts you on the ground at legion.
- paneltest appears in the list, and its circle shows on the map.
- The radius changes to 400.
- After step 5, paneltest is still listed and the button says Remove again.
- After step 6, paneltest is gone.

## Test 5: Test tools
1. Press RFSQ, then tick Senior.
2. Press None.
3. Under Timed transmit, press Start with `3` and `1`. Watch chat.
4. Under Move me, type `-150` and `7700`, and press Go and freeze.
5. Press Release.
6. Press Spot A, then Release.

Pass:
- RFSQ changes the radio to the APX 8000XE. Senior adds a Command channel.
- None gives the UV-5R.
- Chat shows "Radio key down", then "Radio key up".
- Go and freeze moves you and stops you moving. Release lets you move.

## Test 6: Live server view
1. Remove `setr signal_radio_dev_tools 1` from `server.cfg`, and restart the server.
2. On A, open the panel.

Pass: there is no Test tools tab, and no Stand beside button on the Towers tab.

Put the line back to run the other test procedures.

## Results
| Test | Result | Notes |
| --- | --- | --- |
| 1. Open and close | | |
| 2. Old commands are gone | | |
| 3. Radios tab | | |
| 4. Towers tab | | |
| 5. Test tools | | |
| 6. Live server view | | |
