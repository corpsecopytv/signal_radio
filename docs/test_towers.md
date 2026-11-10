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
These use the admin panel steps from `docs/test_core_radio.md`, plus:

| Step | Where it is |
| --- | --- |
| Towers list | The Towers tab shows each tower's ID, sabotage time and cooldown. |
| Show radius | Show radius on map, on the Towers tab, shows or hides each radius on the map. |
| Spot A or B | Test tools, under Move me. |
| Release | Test tools, under Move me. Unfreezes you. |
| Test radio | Place test radio here, and Remove test radio, on Test tools. A stand-in receiving radio for speaker bleed tests. |

Put the radio away before typing `/radioadmin`. Press F6 to open it again.

The test positions north of Paleto Bay are covered only by the Paleto tower:

| Position | Command | Expected signal | Expected bars |
| --- | --- | --- | --- |
| Full | Go to `-150 7700` | Full | 4 |
| Worn | Go to `-150 8000` | Worn | 2 |
| Bad | Go to `-150 8550` | Bad | 1 |
| None | Go to `-150 9000` | None | 0 |

## 1. Towers on the map
A sets profile QPS, opens the Towers tab and presses Show radius on map. A closes the panel and opens the pause map.

- [ ] The list shows nine towers, all online.
- [ ] The map shows nine green circles.
- [ ] Pressing Hide radius on map hides them.

## 2. Signal bars
A turns the radio on, and moves through the four positions in the table.

- [ ] Each position shows the expected bars within a few seconds.
- [ ] Optional, if you have a vehicle spawner: press Release, sit in a vehicle near the Bad position, and check the signal improves.

## 3. Signal audio
B sets profile QPS, stands beside legion, and turns on. A and B stay on QPS OPS 1. B has full signal.

Move A to each position, and transmit with timed transmit `10 5` while listening on B.

- [ ] Full sounds clean.
- [ ] Worn sounds harsher than Full.
- [ ] Bad sounds harsher than Worn.

Move A to None.

- [ ] A's radio shows 0 bars and "Direct".
- [ ] A can key up with no busy tone.
- [ ] B does not hear A, because B is outside direct range.

Keep A at None. B transmits.

- [ ] A does not hear B.

Move A to Full. A starts timed transmit `20 5`. While it runs, A goes to `-150 9000`.

- [ ] B stops hearing A within a few seconds.
- [ ] B's voice has no leftover radio effect afterwards.

## 4. Sabotage interaction
B sets profile None, then stands beside paleto. This proves a civilian can use it, with no item.

- [ ] An orange marker shows at the tower.
- [ ] Standing on it shows "Press E to sabotage".

Press E.

- [ ] B starts a welding animation with a countdown from 120.

Press X.

- [ ] The animation stops, and "Sabotage stopped" shows.
- [ ] The Towers tab shows paleto with no cooldown.

Press E again, then walk 3 metres away.

- [ ] The sabotage stops.

B stands beside paleto and presses E. While B is sabotaging the tower, A stands beside paleto and presses E.

- [ ] The second player gets "Someone is already sabotaging this tower".

B presses X to cancel. Press E twice quickly at the marker.

- [ ] The sabotage starts once and the countdown keeps running. Press X to cancel it.

## 5. Sabotaging a tower
A sets profile QPS, turns on, and goes to `-150 7700`. A has 4 bars.

B stands beside paleto, presses E and waits the full 120 seconds.

- [ ] The server console logs who sabotaged which tower.
- [ ] Staff chat shows the sabotage alert.
- [ ] A's radio shows "Paleto Bay tower offline".
- [ ] A's bars drop to 0 within a few seconds.
- [ ] The Towers tab shows paleto offline, and a cooldown running.
- [ ] No marker shows at paleto while it's sabotaged.

Restart `signal_radio` from the server console while paleto is sabotaged. Set profile QPS on A and turn on.

- [ ] Paleto is still sabotaged, and A still has 0 bars.

Wait for the sabotage to end. It lasts 5 minutes from when it took effect.

- [ ] A's radio shows "Paleto Bay tower back online", and A's bars return to 4.

B presses E at paleto again.

- [ ] "This tower cannot be sabotaged again yet" shows.

Press Clear sabotage on paleto.

- [ ] B can now start sabotaging it again. Press X to cancel it.

## 6. Overlapping coverage
A stands beside legion. B stands beside legion, presses E and waits 120 seconds.

- [ ] Legion Square goes offline, but A keeps signal from nearby towers.

Press Clear sabotage on legion.

## 7. Encrypted noise with no signal
A sets profile QPS, turns on and stands beside legion. B sets profile None, turns on, stands beside mirror, and tunes 450.025. A transmits.

- [ ] B hears the noise and sees "ENC".

B goes to `5000 -5000` while A is transmitting.

- [ ] The noise stops when B's bars reach 0.

## 8. Fireground channel
A and B both set profile RFSQ, and turn on. Both stay in the RFSQ zone and step to Fireground, listed after OPS.

A goes to `-150 9000`. B goes to `-150 9200`. Both are outside all tower coverage and 200 metres apart.

- [ ] Both radios show 4 bars.
- [ ] A and B can hear each other in both directions.

B goes to `-150 9700`, which is 700 metres from A. A transmits.

- [ ] B hears nothing.

## 9. Direct radio
A and B both set profile QPS, turn on, and stay on QPS OPS 1. For each row, move both clients, then have A transmit with timed transmit `10 5` while you listen on B.

| Check | A | B | Expected audio on B |
| --- | --- | --- | --- |
| Baseline | Go to `-150 7700` | Stand beside legion | Normal |
| Close together | Go to `-150 7700` | Go to `-150 7750` | Clearest |
| Worn, far apart | Go to `-150 8000` | Stand beside legion | Worn |
| Worn, 200 metres | Go to `-150 8000` | Go to `-150 8200` | Normal |
| Worn, 50 metres | Go to `-150 8000` | Go to `-150 8050` | Clearest |
| No tower, 50 metres | Go to `-150 9000` | Go to `-150 9050` | Clearest |
| No tower, 300 metres | Go to `-150 9000` | Go to `-150 9300` | Normal |
| No tower, 400 metres | Go to `-150 9000` | Go to `-150 9400` | Worn |
| No tower, 480 metres | Go to `-150 9000` | Go to `-150 9480` | Bad |
| No tower, 600 metres | Go to `-150 9000` | Go to `-150 9600` | Nothing |

- [ ] Each row sounds as expected.
- [ ] "Clearest" is noticeably cleaner than "Normal".
- [ ] In the no-tower rows, both radios show 0 bars and "Direct".

A goes to `-150 7700`. Move B between 7750 and legion while A transmits with timed transmit `20 5`.

- [ ] The audio changes within a few seconds, without needing a new transmission.

Busy check, with both clients at no tower. A goes to `-150 9000`. B goes to `-150 9050`. A starts timed transmit `15 5`. While A is transmitting, B holds the radio key.

- [ ] B gets the busy tone, because B can hear A.

Move B to `-150 9600`, and repeat.

- [ ] B can transmit with no busy tone, because B cannot hear A.

Sabotage check: while paleto is sabotaged, as in test 5, repeat the "Worn, 50 metres" row.

- [ ] A and B can still talk, and both show "Direct".

Civilian check: A and B both set profile None, turn on, and tune to 462.125. A goes to `-150 9000`, and B goes to `-150 9300`. A transmits.

- [ ] B hears A. Civilians can use direct radio too.

## 10. Speaker bleed
One person can't be a talker, a receiving radio and a listener, so this uses a stand-in radio.

A sets profile QPS, turns on, stays on QPS OPS 1, and goes to Spot A. B sets profile None, leaves the radio off, and goes to Spot B. They are 150 metres apart.

B presses Place test radio here. B reads A's ID on the Radios tab, then watches that ID.

For each row, B moves, then A transmits with timed transmit `10 5` while you listen on B.

| B's position | Command | Expected on B |
| --- | --- | --- |
| 5 metres from the radio | Go to `-1181 -3044 20` | Muffled, medium volume |
| 1 metre from the radio | Go to `-1185 -3044 20` | Muffled, louder |
| 9 metres from the radio | Go to `-1177 -3044 20` | Muffled, quiet |
| 15 metres from the radio | Go to `-1171 -3044 20` | Nothing |

- [ ] Each row sounds as expected, and clearly muffled compared with a normal radio.
- [ ] B hears OPS 1, which proves encrypted talkgroups bleed.

Stay at 5 metres. A starts timed transmit `20 5`. While A is transmitting, B moves to 15 metres.

- [ ] The audio stops within a second or so.

Move B back to 5 metres. A transmits, then stops.

- [ ] The audio stops when A stops, and B's normal voice has no leftover effect.

B sets profile None, turns on, and tunes to 450.025. A transmits.

- [ ] B hears only noise and sees "ENC". A radio on that encrypted frequency does not also get bleed.

B turns the radio off, and stays at 5 metres. A transmits.

- [ ] B hears bleed again.

B presses Remove test radio. A transmits.

- [ ] B no longer hears bleed.

This does not prove bleed from a real second radio. Check that when you next have other players online.

## 11. Tower controls
A presses Release, then walks to a spot. On the Towers tab, A types `testsite` and `800`, and presses Add at my position.

- [ ] The Towers tab includes testsite.
- [ ] Show radius on map shows its circle.
- [ ] Setting testsite's radius to 400 shrinks the circle.

Restart `signal_radio`, then press Show radius on map again.

- [ ] testsite is still there, and the circle is still 400.

Press Remove on testsite, then Confirm remove.

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
| 11. Tower controls | | |

## After testing
Stand at each real site you want and add it on the Towers tab. Press Remove on each placeholder. The saved list replaces `config/towers.lua` once you change it.

Adjust the `sr_near`, `sr_full`, `sr_worn`, `sr_bad` and `sr_bleed` values in `client/audio.lua` if the audio needs tuning.
