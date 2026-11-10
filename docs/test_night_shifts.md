# Test procedure: Night Shifts MDT

One person runs this on one PC, with two FiveM clients, on the dev server. Client 1 is A. Client 2 is B. A uses the MDT. B uses a dev profile and listens. Allow about 30 minutes.

## What this run does not cover
- The command channel. Senior ranks are not decided, so a shift does not give it.
- Two officers on the MDT at once. Both clients use one Rockstar licence, and the MDT tracks officers by licence.

## Setup
1. Install Night Shifts on the dev server in a folder named `night_shifts_mdt`. Install oxmysql and a database, as its install guide says.
2. Add `ensure night_shifts_mdt` to `server.cfg`, above the `signal_radio` line.
3. Keep `setr signal_radio_dev_tools 1` in the dev `server.cfg`.
4. Create the QPS and QFD departments in the MDT, each with one rank.
5. Restart the server. The resource has new files.
6. Start both clients in windowed mode, side by side.
7. On B, set profile QPS, turn the radio on and select QPS OPS 1.

Pass: the server console shows Night Shifts started and no `signal_radio` errors. It also prints that no departments are set.

Night Shifts can refuse a second client that has the same identifier. If it refuses B, run the tests with A alone and skip the checks on B. Those checks then need a second GTA V licence.

The admin panel steps are in `docs/test_core_radio.md`.

## Test 1: Read the real data
1. On A, start a shift in QPS, with a callsign.
2. On A, type `/radioadmin` and open the Night Shifts tab.
3. Read the ID of each department in the Departments table.
4. Copy the IDs into `departments` in `signal_radio/config/night_shifts.lua`. For example: `[1] = 'qps'`.
5. Run `ensure signal_radio` in the server console.
6. Open the Night Shifts tab again, and choose A under Shift data.

Pass:
- Shift data shows `isOnShift` as true, with `departmentId` and `callsign`.
- Shift data has a `statusCode` field. If it does not, MDT-to-radio panic cannot work. Report the field names you see.

## Test 2: Start a shift
1. On A, end the shift. Wait 5 seconds.
2. Check that A has the UV-5R.
3. Start a QPS shift with the callsign `L-42`. Wait 5 seconds.

Pass: A's radio changes to the APX 2000 and turns off. After power on, it shows `L-42`.

## Test 3: Callsign
1. On A, turn the radio on and select QPS OPS 1.
2. Change the callsign in the MDT to `L-21`. Wait 5 seconds.
3. On A, type `/callsign X9`.

Pass:
- A's radio shows `L-21` and stays on.
- B's unit list shows `L-21`.
- The chat says the callsign comes from the MDT, and the callsign does not change.

## Test 4: Change department
1. On A, end the shift and start a QFD shift within 5 seconds.
2. Wait 5 seconds.

Pass: A's radio changes to the APX 8000XE and turns off.

## Test 5: End a shift
1. On A, turn the radio on and talk. Check that B cannot hear you, as you are on a QFD talkgroup.
2. Start a QPS shift again and select QPS OPS 1. Check that B hears A.
3. End the shift. Wait 5 seconds.
4. On A, turn the radio on and tune to the QPS OPS 1 frequency. Talk on B.

Pass: A has the UV-5R. A hears only noise, and sees ENC.

## Test 6: Radio panic reaches the MDT
1. On A, start a QPS shift and turn the radio on, on QPS OPS 1.
2. Press the emergency button on A's radio.
3. Open the MDT.

Pass:
- A and B hear the panic tone.
- A's MDT status changes to panic.

Record whether a panic marker appears on the MDT map. The export guide does not say.

## Test 7: MDT panic reaches the radio
1. Set A's MDT status back to available. Wait 35 seconds for the panic cooldown.
2. Trigger a panic from the MDT, as your Night Shifts config allows.
3. Wait 5 seconds.

Pass: A and B hear the panic tone, and B sees A's callsign. The tone plays once.

If the tone does not play, open the Night Shifts tab during the panic and choose A. Compare `statusCode` with `panicStatusCodes` in `config/night_shifts.lua`.

## Test 8: Man-down
If your server respawns you within 30 seconds, set `delayMs` to `1000` in `config/night_shifts.lua` for this test. Run `ensure signal_radio`. Put it back afterwards.

1. On A, stay on shift and turn the radio on.
2. Die in-game, for example by falling from a tall building. Stay dead until the delay ends.
3. Open the MDT.

Pass: the MDT has one new call, of type `Panic`, at A's position, for police and ambulance, naming A's callsign.

## Test 9: No false man-down
1. Turn A's radio off and die again.
2. End the shift, turn the radio on and die again.

Pass: neither death creates a call.

## Test 10: Night Shifts stops
1. On A, start a shift and turn the radio on.
2. In the server console, run `stop night_shifts_mdt`.
3. Wait 10 seconds and talk on A.
4. Run `ensure night_shifts_mdt`.

Pass: A's radio stays on the emergency talkgroup while Night Shifts is stopped, and B hears A. The console shows no `signal_radio` errors.
