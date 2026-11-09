# Test procedure: towers, signal, jammer and fireground

One person runs this on one PC, with two FiveM clients, on the dev server. Client 1 is A. Client 2 is B. Allow about 45 minutes, including one 5 minute wait.

## What this run does not cover
- The full 30 minute cooldown. Test 5 confirms it starts. The logic checks cover when it ends.
- The vehicle signal bonus, unless you add the optional step in test 2.
- Real tower sites. The nine towers are placeholders.

## Setup
1. Copy the latest `signal_radio` folder to `resources/[radio]/signal_radio`, replacing the old one.
2. Use the same `server.cfg` lines as `docs/test_core_radio.md`.
3. Restart the server. The resource has new files.
4. Start both clients in windowed mode, side by side.

Pass: the server console shows no `signal_radio` errors.

## How to run these tests
These work with the commands from `docs/test_core_radio.md`, plus:

| Command | What it does |
| --- | --- |
| `/radio_tower list` | Shows each tower's id, jam time and cooldown. |
| `/radio_tower_debug` | Shows or hides each tower's radius on the map. |
| `/vp_goto <x> <y>` | Moves you there and freezes you. |
| `/vp_tower <id>` | Stands you on the ground beside a tower. |
| `/vp_spot off` | Releases you from a freeze. |

Put the radio away before typing a command. Press F6 to open it again.

The test positions north of Paleto Bay are covered only by the Paleto tower:

| Position | Command | Expected signal | Expected bars |
| --- | --- | --- | --- |
| Full | `/vp_goto -150 7700` | Full | 4 |
| Worn | `/vp_goto -150 8000` | Worn | 2 |
| Bad | `/vp_goto -150 8550` | Bad | 1 |
| None | `/vp_goto -150 9000` | None | 0 |

## 1. Towers on the map
A runs `/radio_dev qps`, then `/radio_tower list` and `/radio_tower_debug`. Open the pause map.

- [ ] The list shows nine towers, all online.
- [ ] The map shows nine green circles.
- [ ] Running `/radio_tower_debug` again hides them.

## 2. Signal bars
A turns the radio on, and moves through the four positions in the table.

- [ ] Each position shows the expected bars within a few seconds.
- [ ] Optional: at the Bad position, sitting in a vehicle improves the signal.

## 3. Signal audio
B runs `/radio_dev qps`, then `/vp_tower legion`, and turns on. A and B stay on QPS OPS 1. B has full signal.

Move A to each position, and transmit with `/vp_tx 10 5` while listening on B.

- [ ] Full sounds clean.
- [ ] Worn sounds harsher than Full.
- [ ] Bad sounds harsher than Worn.

Move A to None.

- [ ] A's radio key gives the busy tone and shows "No signal".
- [ ] B does not hear A.

Keep A at None. B transmits.

- [ ] A does not hear B.

Move A to Full. A runs `/vp_tx 20 5`. While it runs, A runs `/vp_goto -150 9000`.

- [ ] A's transmission cuts off once the radio updates, within a few seconds.
- [ ] B's voice has no leftover radio effect afterwards.

## 4. Jammer interaction
B runs `/radio_dev off`, then `/vp_tower paleto`. This proves a civilian can use it, with no item.

- [ ] An orange marker shows at the tower.
- [ ] Standing on it shows "Press E to install a jammer".

Press E.

- [ ] B starts a welding animation with a countdown from 120.

Press X.

- [ ] The animation stops, and "Jammer install stopped" shows.
- [ ] `/radio_tower list` shows paleto with no cooldown.

Press E again, then walk 3 metres away.

- [ ] The install stops.

Press E on A's client too, by running `/vp_tower paleto` on A, while B is installing.

- [ ] The second player gets "Someone is already installing a jammer".

## 5. Jamming a tower
A runs `/radio_dev qps`, turns on, and runs `/vp_goto -150 7700`. A has 4 bars.

B runs `/vp_tower paleto`, presses E and waits the full 120 seconds.

- [ ] The server console logs who jammed which tower.
- [ ] Staff chat shows the jam alert.
- [ ] A's radio shows "Paleto Bay tower offline".
- [ ] A's bars drop to 0 within a few seconds.
- [ ] `/radio_tower list` shows paleto jammed, and a cooldown running.
- [ ] No marker shows at paleto while it's jammed.

Restart `signal_radio` from the server console while paleto is jammed. Run `/radio_dev qps` on A and turn on.

- [ ] Paleto is still jammed, and A still has 0 bars.

Wait for the jam to end. It lasts 5 minutes from when it took effect.

- [ ] A's radio shows "Paleto Bay tower back online", and A's bars return to 4.

B presses E at paleto again.

- [ ] "This tower cannot be jammed again yet" shows.

Run `/radio_tower clear paleto`.

- [ ] B can now start an install. Press X to cancel it.

## 6. Overlapping coverage
A runs `/vp_tower legion`. B runs `/vp_tower legion`, presses E and waits 120 seconds.

- [ ] Legion Square goes offline, but A keeps signal from nearby towers.

Run `/radio_tower clear legion`.

## 7. Encrypted noise with no signal
A runs `/radio_dev qps`, turns on and runs `/vp_tower legion`. B runs `/radio_dev off`, turns on, stands at `/vp_tower mirror`, and tunes 450.025. A transmits.

- [ ] B hears the noise and sees "ENC".

B runs `/vp_goto 5000 -5000` while A is transmitting.

- [ ] The noise stops when B's bars reach 0.

## 8. Fireground channel
A and B both run `/radio_dev rfsq`, and turn on. Both stay in the RFSQ zone and step to Fireground, listed after OPS.

A runs `/vp_goto -150 9000`. B runs `/vp_goto -150 9200`. Both are outside all tower coverage and 200 metres apart.

- [ ] Both radios show 4 bars.
- [ ] A and B can hear each other in both directions.

B runs `/vp_goto -150 9700`, which is 700 metres from A. A transmits.

- [ ] B hears nothing.
- [ ] A and B on any other talkgroup at this position get "No signal".

## 9. Tower commands
A runs `/vp_spot off`, then walks to a spot and runs `/radio_tower add testsite 800`.

- [ ] `/radio_tower list` includes testsite.
- [ ] `/radio_tower_debug` shows its circle.
- [ ] `/radio_tower radius testsite 400` shrinks the circle.

Restart `signal_radio`.

- [ ] testsite is still there, and the circle is still 400.

Run `/radio_tower remove testsite`.

## Results
| Test | Result | Notes |
| --- | --- | --- |
| 1. Towers on the map | | |
| 2. Signal bars | | |
| 3. Signal audio | | |
| 4. Jammer interaction | | |
| 5. Jamming a tower | | |
| 6. Overlapping coverage | | |
| 7. Encrypted noise with no signal | | |
| 8. Fireground channel | | |
| 9. Tower commands | | |

## After testing
Stand at each real site you want and run `/radio_tower add <id> <radius>`. Use `/radio_tower remove <id>` for the placeholders. The saved list replaces `config/towers.lua` once you change it.

Adjust the `sr_worn` and `sr_bad` values in `client/audio.lua` if the audio needs tuning.
