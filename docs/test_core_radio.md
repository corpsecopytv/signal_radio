# Test procedure: core radio and handsets

One person runs this on one PC, with two FiveM clients. Client 1 is A. Client 2 is B. Run it on the dev server, never on the live server.

It covers build `566fae8` on `feat/voice-proof`, plus any later commits on that branch.

You need a headset with a microphone. Allow about 60 minutes.

## What this run does not cover
- Night Shifts MDT, towers, signal quality, jammers and the dispatch console. These are not built yet.
- Overlapping talkers from three or more players, and the load test. These need real players.
- The `radio.priority` ACE. Test 5 proves priority through panic instead.
- Spectator mode hearing encrypted voice. This is a known open gap.

## Setup
1. Keep the patched pma-voice from the voice proof.
2. Copy the latest `signal_radio` folder to `resources/[radio]/signal_radio`, replacing the old one.
3. Make sure the dev `server.cfg` has these lines:

```
setr voice_useNativeAudio true
setr voice_enableSubmix 1
setr voice_enableRadios 1
setr voice_onClickVolume 0
setr voice_offClickVolume 0
setr voice_disableAutomaticListenerOnCamera 1
setr signal_radio_dev_profiles 1
setr signal_radio_voice_proof 1
add_ace builtin.everyone radio.admin allow
ensure pma-voice
ensure signal_radio
```

4. Restart the server. A resource refresh is not enough, because the resource has new files.
5. Start both clients, as in `docs/voice_proof.md`. Run them in windowed mode, side by side.
6. A runs `/vp_spot a`. B runs `/vp_spot b`. The spots are 150 metres apart.

Pass: the server console shows no `signal_radio` or `pma-voice` errors.

## How to run these tests
- **Keyboard focus:** While the radio is open, it takes your keyboard. Press Esc or use "Put radio away" before typing a chat command.
- **Open the radio:** Press F6.
- **Talk on the radio:** With the radio put away, hold Left Alt. With it open, hold the side bar on the left.
- **Timed transmit:** Put the radio away and run `/vp_tx 10 5`. Switch to the other client within 5 seconds, then talk until "Radio key up" appears.
- **Find a server id:** Run `/vp_state <channel>`. It marks your own id. A talkgroup's channel is its number in `config/talkgroups.lua`. A frequency's channel is its value in kHz, so 462.125 is 462125.
- **Check that voice arrives:** Run `/vp_watch <talker id>`, and read the result in chat or the F8 console.
- **Do not use `/vp_fx`.** It replaces the radio's audio settings until the resource restarts.
- **One account:** Both clients share your Rockstar account, so they share a callsign and saved scan choices. This is expected. The test does not need separate callsigns.

Tick each line as it passes. If one fails, note the test number, what you saw, and any error in the F8 or server console.

## 1. Skins and handset basics
A runs each command, then presses F6 to look at the radio.

| Command | Expected radio |
| --- | --- |
| `/radio_dev qps` | APX 2000 |
| `/radio_dev qas` | APX 2000 |
| `/radio_dev qfd` | APX 8000XE hi-vis |
| `/radio_dev rfsq` | APX 8000XE hi-vis |
| `/radio_dev off` | UV-5R |

- [ ] Each command shows the expected radio.
- [ ] The radio has no white box around it over the game.

A runs `/radio_dev qps senior`, and opens the radio.

- [ ] Clicking the left knob turns the radio on, with a power tone.
- [ ] The screen shows QPS and OPS 1.
- [ ] Hovering over a control highlights it, and the highlight sits on the real control.
- [ ] D-pad left and right, the tall knob, and scrolling over it all change channel.
- [ ] D-pad up and down change the volume, and you hear the difference on the next transmission.
- [ ] Number keys 1 to 3 jump to that channel in the zone.
- [ ] Dragging the Motorola badge moves the radio.
- [ ] Reconnecting A puts the radio back in the dragged position.
- [ ] Esc puts the radio away, and the game gets the mouse back.
- [ ] The status strip shows the zone and channel while the radio is away.

## 2. Talking on a talkgroup
A runs `/radio_dev qps senior`. B runs `/radio_dev qps`. Turn both radios on. Both stay on QPS OPS 1.

B runs `/vp_state 1001`, notes A's id, then runs `/vp_watch <A id>`. A transmits.

- [ ] B shows `VOICE ARRIVING`, and you hear the radio effect.
- [ ] A's screen turns rose and shows "Transmitting".
- [ ] B's screen turns amber and shows A's callsign.
- [ ] You hear the grant tone on A, and a short receive tone on B.
- [ ] When A stops, both screens return to green-grey.

B changes to OPS 2. A transmits.

- [ ] B stays silent.

Return B to OPS 1.

## 3. Units and callsign
- [ ] On either radio, the Units key lists both units. Your own shows "(you)".
- [ ] Back returns to the channel screen.
- [ ] After B changes channel and returns, the list on A is correct.
- [ ] `/callsign Bravo-12` changes the callsign on the screen.

## 4. Zones and lists
- [ ] The Zone key on A lists Frequency, QPS, QAS, QFD, RFSQ and Interop.
- [ ] D-pad up and down move the highlight, and the list scrolls to show every row.
- [ ] D-pad left and right do nothing while the list is open.
- [ ] Select chooses the highlighted zone.
- [ ] The keyboard arrows and Enter also work.
- [ ] The small dot marks your current zone.

Run `/radio_dev rfsq` on A, and turn the radio on.

- [ ] The RFSQ radio lists every zone, with RFSQ first.

Run `/radio_dev qps` on A, then open QPS in the Zone list.

- [ ] Command is missing for a non-senior radio.

Run `/radio_dev qps senior` on A.

- [ ] Command appears.

Run `/radio_dev qfd` on B. Turn both radios on. A moves to the QFD zone on OPS. A transmits.

- [ ] B hears A, showing that a QPS radio can reach another department.

## 5. Busy channel and panic
A and B both run `/radio_dev qps`. Both go to QPS OPS 1.

A runs `/vp_tx 15 5`. Switch to B. While A is transmitting, hold Left Alt on B and talk.

- [ ] B gets a busy tone and "Channel busy" shows when the radio is open.
- [ ] A's client does not receive B's voice.
- [ ] After A stops, B can transmit normally.
- [ ] After that, B's normal voice has no leftover radio effect on A.

On A, hold the orange emergency button.

- [ ] A quick click does nothing. A full hold sends the alert.
- [ ] Both radios flash orange and show "Emergency", with A's callsign. The panic tone plays.
- [ ] The alert clears after about 8 seconds.
- [ ] A second hold within 30 seconds shows the wait message.

Within 60 seconds of A's panic, B runs `/vp_tx 15 3`. While B is transmitting, A holds Left Alt and talks.

- [ ] A is not blocked, because panic gives priority.

## 6. Scan list
A and B both run `/radio_dev qps`. Turn both radios on. A stays on QPS OPS 1. B moves to OPS 2.

On A, press Scan.

- [ ] The list shows "Scan: off", then every talkgroup. OPS 1, OPS 2 and Interop have ticks.
- [ ] Select on the top row changes it to "Scan: on".
- [ ] The "Scan" tag appears on the channel screen.

B transmits on OPS 2.

- [ ] A hears B at a lower volume, and the screen shows B's callsign and "on OPS 2".
- [ ] A's Left Alt still transmits on OPS 1. B does not receive it.

On A, untick OPS 2. B transmits.

- [ ] A stops hearing B straight away.

On A, tick QAS OPS. Move B to the QAS zone, on OPS. B transmits.

- [ ] A hears B on another department's talkgroup.

Reconnect A, and run `/radio_dev qps`. Open the Scan list.

- [ ] QAS OPS is still ticked, and OPS 2 is still unticked.
- [ ] Scan shows off.

## 7. Civilian radio tuning
A runs `/radio_dev off`. Turn the radio on using the top knob. It starts on 476.425.

- [ ] The screen shows UHF and 476.425, with no channel names.
- [ ] Typing on the radio's number keys shows digits filling in, such as `462.___`.
- [ ] The `*` key deletes the last digit.
- [ ] EXIT clears a part-typed frequency.
- [ ] The sixth digit tunes the frequency.
- [ ] The keyboard's top-row digits and number pad both work. Backspace deletes.
- [ ] Typing `300000` shows "out of band", and the frequency does not change.
- [ ] ▲ and ▼ step by 0.025.
- [ ] Scrolling over the knob changes volume.
- [ ] BAND opens VHF and UHF. ▲ and ▼ move the highlight. MENU selects it, and the radio jumps to that band.
- [ ] MENU on the channel screen opens Units. EXIT returns.
- [ ] VFO/MR and A/B do nothing.
- [ ] There is no emergency button zone and no Scan option.

## 8. Civilians talking
A and B both run `/radio_dev off`. Both turn on, and both tune to 462.125.

B runs `/vp_state 462125`, notes A's id, then runs `/vp_watch <A id>`. A transmits.

- [ ] B shows `VOICE ARRIVING`, and you hear A.
- [ ] B's screen turns amber and shows "Receiving", with no name.
- [ ] A's square indicator below VFO/MR lights red.
- [ ] B's square indicator stays dark while receiving.

B tunes to 462.150. A transmits.

- [ ] B stays silent.

## 9. Civilian on an emergency frequency
A runs `/radio_dev qps`, turns on and stays on QPS OPS 1. B runs `/radio_dev off`, turns on and tunes to 450.025.

Keep the clients at spots a and b. Check that B is not spectating.

A runs `/vp_state 1001` and notes A's id. B runs `/vp_watch <A id>`. A transmits.

- [ ] B hears only noise while A transmits, and the noise stops when A stops.
- [ ] B's screen turns amber and shows "ENC", with no callsign.
- [ ] `/vp_watch` on B stays on silent.
- [ ] B's push-to-talk does nothing, and A receives nothing.
- [ ] Tuning B away during a transmission stops the noise.

Control: B runs `/radio_dev qps`, and turns on. A transmits.

- [ ] B shows `VOICE ARRIVING`. This proves the watch works.

## 10. Emergency frequency mode
A runs `/radio_dev qps`. B runs `/radio_dev off`. Turn both on. B tunes to 462.125.

On A, press Zone, then select Frequency.

- [ ] A shows a frequency and UHF or VHF, with Units and Zone on the soft keys.
- [ ] Typing shows digits, and the right soft key changes to Clear.
- [ ] The `0` and `*` keys work.
- [ ] D-pad left and right step the frequency.

A tunes to 462.125.

- [ ] A and B can hear each other in both directions.

B runs `/radio_dev qfd`, turns on and stays on QFD OPS. A types 450.225. A transmits.

- [ ] B hears A with clear audio.

Repeat the digit checks on the APX 8000XE. Run `/radio_dev qfd` on A, and enter frequency mode.

- [ ] The `0` and `*` keys work on the fire radio too.

Junior check: A runs `/radio_dev qps`, and enters frequency mode. B runs `/radio_dev qps senior`, turns on, and moves to QPS Command. A types 450.075. B transmits.

- [ ] A hears only noise and sees "ENC".

On A, press Zone, then choose QPS.

- [ ] A returns to a named channel, and the noise stops.

Scan check: On A, turn scan on from the Scan list. Enter frequency mode, then return to a zone.

- [ ] The "Scan" tag is hidden in frequency mode, and scanning resumes in zone mode.

## 11. Cleanup
A and B both run `/radio_dev qps`, and go to OPS 1.

A runs `/vp_tx 20 5`. While A is transmitting, restart `signal_radio` from the server console.

- [ ] The server console shows no errors.
- [ ] The game keeps its mouse and keyboard on both clients.

A presses Left Alt once to clear the key. Both clients run `/radio_dev qps` again, and turn on.

- [ ] A and B can talk normally on OPS 1.
- [ ] Neither client has a stuck radio effect on normal voice.

Close B's client while it is on a channel.

- [ ] The server console shows no errors.
- [ ] A's Units list drops B.

## Results
| Test | Result | Notes |
| --- | --- | --- |
| 1. Skins and handset basics | | |
| 2. Talking on a talkgroup | | |
| 3. Units and callsign | | |
| 4. Zones and lists | | |
| 5. Busy channel and panic | | |
| 6. Scan list | | |
| 7. Civilian radio tuning | | |
| 8. Civilians talking | | |
| 9. Civilian on an emergency frequency | | |
| 10. Emergency frequency mode | | |
| 11. Cleanup | | |

## When done
Remove `setr signal_radio_dev_profiles 1`, `setr signal_radio_voice_proof 1` and the `add_ace` line from the dev `server.cfg` if other people use that server.
