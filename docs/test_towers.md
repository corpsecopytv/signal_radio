# Test procedure: towers, signal, sabotage and fireground

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
| `/radio_tower list` | Shows each tower's id, sabotage time and cooldown. |
| `/radio_tower_debug` | Shows or hides each tower's radius on the map. |
| `/vp_goto <x> <y>` | Moves you there and freezes you. |
| `/vp_tower <id>` | Stands you on the ground beside a tower. |
| `/vp_spot off` | Releases you from a freeze. |
| `/vp_bleedtest <here, off>` | Places or removes a stand-in receiving radio, for speaker bleed tests. |

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

- [ ] A's radio shows 0 bars and "Direct".
- [ ] A can key up with no busy tone.
- [ ] B does not hear A, because B is outside direct range.

Keep A at None. B transmits.

- [ ] A does not hear B.

Move A to Full. A runs `/vp_tx 20 5`. While it runs, A runs `/vp_goto -150 9000`.

- [ ] B stops hearing A within a few seconds.
- [ ] B's voice has no leftover radio effect afterwards.

## 4. Sabotage interaction
B runs `/radio_dev off`, then `/vp_tower paleto`. This proves a civilian can use it, with no item.

- [ ] An orange marker shows at the tower.
- [ ] Standing on it shows "Press E to sabotage".

Press E.

- [ ] B starts a welding animation with a countdown from 120.

Press X.

- [ ] The animation stops, and "Sabotage stopped" shows.
- [ ] `/radio_tower list` shows paleto with no cooldown.

Press E again, then walk 3 metres away.

- [ ] The sabotage stops.

Press E on A's client too, by running `/vp_tower paleto` on A, while B is sabotaging the tower.

- [ ] The second player gets "Someone is already sabotaging this tower".

## 5. Sabotaging a tower
A runs `/radio_dev qps`, turns on, and runs `/vp_goto -150 7700`. A has 4 bars.

B runs `/vp_tower paleto`, presses E and waits the full 120 seconds.

- [ ] The server console logs who sabotaged which tower.
- [ ] Staff chat shows the sabotage alert.
- [ ] A's radio shows "Paleto Bay tower offline".
- [ ] A's bars drop to 0 within a few seconds.
- [ ] `/radio_tower list` shows paleto sabotaged, and a cooldown running.
- [ ] No marker shows at paleto while it's sabotaged.

Restart `signal_radio` from the server console while paleto is sabotaged. Run `/radio_dev qps` on A and turn on.

- [ ] Paleto is still sabotaged, and A still has 0 bars.

Wait for the sabotage to end. It lasts 5 minutes from when it took effect.

- [ ] A's radio shows "Paleto Bay tower back online", and A's bars return to 4.

B presses E at paleto again.

- [ ] "This tower cannot be sabotaged again yet" shows.

Run `/radio_tower clear paleto`.

- [ ] B can now start sabotaging it again. Press X to cancel it.

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

## 9. Direct radio
A and B both run `/radio_dev qps`, turn on, and stay on QPS OPS 1. For each row, move both clients, then have A transmit with `/vp_tx 10 5` while you listen on B.

| Check | A | B | Expected audio on B |
| --- | --- | --- | --- |
| Baseline | `/vp_goto -150 7700` | `/vp_tower legion` | Normal |
| Close together | `/vp_goto -150 7700` | `/vp_goto -150 7750` | Clearest |
| Worn, far apart | `/vp_goto -150 8000` | `/vp_tower legion` | Worn |
| Worn, 200 metres | `/vp_goto -150 8000` | `/vp_goto -150 8200` | Normal |
| Worn, 50 metres | `/vp_goto -150 8000` | `/vp_goto -150 8050` | Clearest |
| No tower, 50 metres | `/vp_goto -150 9000` | `/vp_goto -150 9050` | Clearest |
| No tower, 300 metres | `/vp_goto -150 9000` | `/vp_goto -150 9300` | Normal |
| No tower, 400 metres | `/vp_goto -150 9000` | `/vp_goto -150 9400` | Worn |
| No tower, 480 metres | `/vp_goto -150 9000` | `/vp_goto -150 9480` | Bad |
| No tower, 600 metres | `/vp_goto -150 9000` | `/vp_goto -150 9600` | Nothing |

- [ ] Each row sounds as expected.
- [ ] "Clearest" is noticeably cleaner than "Normal".
- [ ] In the no-tower rows, both radios show 0 bars and "Direct".

Move B between 7750 and legion while A transmits with `/vp_tx 20 5`.

- [ ] The audio changes within a few seconds, without needing a new transmission.

Busy check, with both clients at no tower. A runs `/vp_goto -150 9000`. B runs `/vp_goto -150 9050`. A runs `/vp_tx 15 5`. While A is transmitting, B holds the radio key.

- [ ] B gets the busy tone, because B can hear A.

Move B to `/vp_goto -150 9600`, and repeat.

- [ ] B can transmit with no busy tone, because B cannot hear A.

Sabotage check: while paleto is sabotaged, as in test 5, repeat the "Worn, 50 metres" row.

- [ ] A and B can still talk, and both show "Direct".

Civilian check: A and B both run `/radio_dev off`, turn on, and tune to 462.125. A runs `/vp_goto -150 9000`, and B runs `/vp_goto -150 9300`. A transmits.

- [ ] B hears A. Civilians can use direct radio too.

## 10. Speaker bleed
One person can't be a talker, a receiving radio and a listener, so this uses a stand-in radio.

A runs `/radio_dev qps`, turns on, stays on QPS OPS 1, and runs `/vp_spot a`. B runs `/radio_dev off`, leaves the radio off, and runs `/vp_spot b`. They are 150 metres apart.

B runs `/vp_bleedtest here`. B runs `/vp_state 1001` to note A's id, then `/vp_watch <A id>`.

For each row, B moves, then A transmits with `/vp_tx 10 5` while you listen on B.

| B's position | Command | Expected on B |
| --- | --- | --- |
| 5 metres from the radio | `/vp_goto -1181 -3044 20` | Muffled, medium volume |
| 1 metre from the radio | `/vp_goto -1185 -3044 20` | Muffled, louder |
| 9 metres from the radio | `/vp_goto -1177 -3044 20` | Muffled, quiet |
| 15 metres from the radio | `/vp_goto -1171 -3044 20` | Nothing |

- [ ] Each row sounds as expected, and clearly muffled compared with a normal radio.
- [ ] B hears OPS 1, which proves encrypted talkgroups bleed.

Stay at 5 metres. A runs `/vp_tx 20 5`. While A is transmitting, B moves to 15 metres.

- [ ] The audio stops within a second or so.

Move B back to 5 metres. A transmits, then stops.

- [ ] The audio stops when A stops, and B's normal voice has no leftover effect.

B runs `/radio_dev off`, turns on, and tunes to 450.025. A transmits.

- [ ] B hears only noise and sees "ENC". A radio on that encrypted frequency does not also get bleed.

B runs `/vp_bleedtest off`. A transmits.

- [ ] B no longer hears bleed.

This does not prove bleed from a real second radio. Check that when you next have other players online.

## 11. Tower commands
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
| 4. Sabotage interaction | | |
| 5. Sabotaging a tower | | |
| 6. Overlapping coverage | | |
| 7. Encrypted noise with no signal | | |
| 8. Fireground channel | | |
| 9. Direct radio | | |
| 10. Speaker bleed | | |
| 11. Tower commands | | |

## After testing
Stand at each real site you want and run `/radio_tower add <id> <radius>`. Use `/radio_tower remove <id>` for the placeholders. The saved list replaces `config/towers.lua` once you change it.

Adjust the `sr_near`, `sr_worn`, `sr_bad` and `sr_bleed` values in `client/audio.lua` if the audio needs tuning.
