# Step 1: voice proof

One person runs this on one PC, with two FiveM clients. Client 1 is A. Client 2 is B. Run it on a separate dev server, never on the live server.

You need a headset with a microphone. A headset stops the second client feeding back into your microphone.

## Limits of a solo test
- This proves the voice path between two clients. It does not replace a test with real players.
- The load test in the plan still needs 10 or more real players before launch.
- Both clients use the same microphone, so your own voice is the test signal.

## Install
1. Install pma-voice 7.0.1, commit `6c9d96e`.
2. Open a terminal inside the `pma-voice` folder.
3. Run `git apply --ignore-whitespace path/to/signal_radio.patch`.
4. Copy the `signal_radio` resource folder to `resources/[radio]/signal_radio`.
5. Add these lines to the dev `server.cfg`:

```
setr voice_useNativeAudio true
setr voice_enableSubmix 1
setr voice_enableRadios 1
setr signal_radio_voice_proof 1
add_ace builtin.everyone radio.admin allow
ensure pma-voice
ensure signal_radio
```

The `add_ace` line gives every player admin radio commands. Never use it on the live server.

Run only the default Cfx resources and these two. Do not run a framework or Night Shifts for this test, because they can refuse a second client with the same identifier.

## Start two clients
1. Right-click `FiveM.exe` at `%LOCALAPPDATA%\FiveM\FiveM.exe`, and create two shortcuts.
2. Open the second shortcut's Properties. Add ` -cl2` after the closing quote in Target.
3. Start the first shortcut and connect to the dev server. Wait until it is fully loaded.
4. Start the second shortcut and connect to the same server.

This is the method in the FiveM docs. It keeps the same identifier on both clients.

If the second client gets "account is already being used", stop here. You then need a second GTA V licence, on this PC or another one. Do not use other workarounds from forums, because one forum author reported a ban.

## Commands
| Command | What it does |
| --- | --- |
| `/vp_spot <a, b, off>` | Moves you to a test spot and freezes you, or releases you. |
| `/vp_join <channel>` | Joins a channel as a normal member. |
| `/vp_leave` | Leaves the radio. |
| `/vp_listen <channel> 1` | Listens with audio. |
| `/vp_listen <channel> 0` | Gets talk events only, with no audio. |
| `/vp_unlisten <channel>` | Stops listening. |
| `/vp_state <channel>` | Shows the channel members and their server ids. |
| `/vp_tx [seconds] [delay]` | Holds the radio key on a timer. The default is 10 seconds after a 5 second delay. |
| `/vp_call <number>` | Joins a phone call. Use 0 to leave. |
| `/vp_fx <full, worn, bad, mute, near> [talker id]` | Sets how a talker sounds to you. With no id, it applies to all talkers. |
| `/vp_fx off` | Restores pma-voice default audio. |
| `/vp_watch <talker id>` | Reports when voice arrives from that talker. Run it with no id to stop. |

## How to run a transmission
1. In the transmitting client, run `/vp_tx 10 5`.
2. Switch to the receiving client within 5 seconds.
3. Talk without stopping until "Radio key up" appears.
4. Read the receiving client's output. Press F8 to see it in the console.

`VOICE ARRIVING` from `/vp_watch` is the main result. Your ears are the second check.

If a client is silent in test 1, the unfocused window may not be sending your microphone. Focus the transmitting client, hold Left Alt, and talk. Then read the receiving client's F8 console.

If you can only hear the focused client, use `/vp_watch` for the pass or fail, and judge sound with the talker unfocused.

## Tests
First, A runs `/vp_spot a`, and B runs `/vp_spot b`. The spots are 150 metres apart, so proximity voice does not affect the results.

### 1. Normal channels
- A and B run `/vp_join 1001`.
- A runs `/vp_state 1001`, and notes both server ids.
- B runs `/vp_watch <A id>`. A transmits.
- Pass: B shows `VOICE ARRIVING`, and you hear the radio effect.
- B runs `/vp_join 1002`. A transmits.
- Pass: B stays silent.

### 2. Listen with audio
- B stays on 1002 and runs `/vp_listen 1001 1`. A transmits.
- Pass: B shows `VOICE ARRIVING`.
- A runs `/vp_watch <B id>`. B transmits.
- Pass: A stays silent, because B still transmits on 1002.
- A runs `/vp_watch` to stop.

### 3. Listener cut mid-transmission
- A runs `/vp_tx 20 5`. Switch to B, and talk.
- Once B shows `VOICE ARRIVING`, B runs `/vp_unlisten 1001`.
- Pass: B changes to silent while A is still transmitting.

### 4. Per-talker audio
- B runs `/vp_listen 1001 1`.
- B runs `/vp_fx full`, and A transmits. Repeat with `worn`, `bad`, `mute` and `near`.
- Pass: `worn` is harsher than `full`, and `bad` is harsher than `worn`. `mute` is silent. `near` has no radio effect.
- B runs `/vp_fx full`, then `/vp_fx mute 9999`. A transmits.
- Pass: B still hears A, because the mute applies only to id 9999.
- B runs `/vp_join 1001`, and A transmits. Then B runs `/vp_join 1002` and `/vp_listen 1001 1`, and A transmits.
- Pass: A is quieter as a listen-only channel than as the primary channel.
- B runs `/vp_fx off`.

### 5. Keyless listener
- Confirm that B is not spectating and is not on a scripted camera.
- B runs `/vp_unlisten 1001`, `/vp_listen 1001 0` and `/vp_watch <A id>`.
- A transmits.
- Pass: B hears nothing, and the watch stays on silent.
- Pass: B's console shows "ENC traffic started" and "stopped", with no talker id.
- Control: B runs `/vp_listen 1001 1`, and A transmits.
- Pass: B shows `VOICE ARRIVING`. This proves the watch works.

### 6. Phone call during radio use
- B stays on `/vp_listen 1001 1`. A and B both run `/vp_call 5`.
- A runs `/vp_tx 20 5`. Switch to B, and talk.
- While A is transmitting, B runs `/vp_call 0`.
- Pass: B keeps hearing A on the radio until "Radio key up".
- A runs `/vp_call 0`.

### 7. Cleanup
- A runs `/vp_tx 20 5`. While A is transmitting, restart `signal_radio` from the server console.
- Pass: A's timed transmission ends without a server error.
- A presses and releases Left Alt once to clear the radio key.
- B runs `/vp_watch <A id>`. A runs `/vp_tx 10 5`.
- Pass: B stays silent, because the restart removed its listener.
- B runs `/vp_listen 1001 1`, then closes its client. A runs `/vp_tx 5 0`.
- Pass: the server console shows no error.

## When done
Remove `setr signal_radio_voice_proof 1` and the `add_ace` line from the dev `server.cfg`. Record the results before starting step 2.
