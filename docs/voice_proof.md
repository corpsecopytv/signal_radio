# Step 1: voice proof

Run this on a separate dev server, never on the live server. You need three players: A, B and C.

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
add_ace group.admin radio.admin allow
ensure pma-voice
ensure signal_radio
```

Give all three test players the `radio.admin` ACE. Press F8 to see each command's output in the console.

## Commands
| Command | What it does |
| --- | --- |
| `/vp_join <channel>` | Joins a channel as a normal member. |
| `/vp_leave` | Leaves the radio. |
| `/vp_listen <channel> 1` | Listens with audio. |
| `/vp_listen <channel> 0` | Gets talk events only, with no audio. |
| `/vp_unlisten <channel>` | Stops listening. |
| `/vp_state <channel>` | Shows the channel members. |
| `/vp_fx <full, worn, bad, mute, near> [talker id]` | Sets how a talker sounds to you. With no id, it applies to all talkers. |
| `/vp_fx off` | Restores pma-voice default audio. |
| `/vp_watch <talker id>` | Reports when voice arrives from that talker. Run it with no id to stop. |

## Tests
Stand at least 100 metres apart, so proximity voice does not affect the result.

### 1. Normal channels
- A and B run `/vp_join 1001`. C runs `/vp_join 1002`.
- A talks on the radio.
- Pass: B hears A. C does not hear A.

### 2. Listen with audio
- C runs `/vp_listen 1001 1`.
- A talks.
- Pass: C hears A.
- C talks.
- Pass: A and B do not hear C, because C still transmits on 1002.

### 3. Listener cut mid-transmission
- A holds the radio key.
- C runs `/vp_unlisten 1001`.
- Pass: C stops hearing A at once, while A is still talking.

### 4. Per-talker audio
- C runs `/vp_listen 1001 1`, then `/vp_fx worn <A id>`.
- A talks. B talks.
- Pass: A sounds worn to C, and B sounds clean to C, at a lower scan volume.
- C repeats with `bad`, `mute` and `near`.
- Pass: `bad` is harsher than `worn`. `mute` is silent. `near` plays without the radio effect.
- C runs `/vp_fx off`.

### 5. Keyless listener
- Confirm that C is not spectating and is not on a scripted camera.
- C runs `/vp_unlisten 1001`, then `/vp_listen 1001 0`, then `/vp_watch <A id>`.
- A talks.
- Pass: C hears nothing, the watch stays on "silent", and the console shows "ENC traffic started" and "stopped" with no talker id.
- Control: C runs `/vp_listen 1001 1`. A talks.
- Pass: the watch shows "VOICE ARRIVING". This proves the watch works.
- A and C must stay within OneSync scope, about 400 metres. If the watch says "out of scope", move closer.

### 6. Cleanup
- C runs `/vp_listen 1001 1`, and A holds the radio key.
- Restart `signal_radio`.
- Pass: C stops hearing A, and A's next transmission does not reach C.
- C reconnects after running `/vp_listen 1001 1` again.
- Pass: A's next transmission works, and `/vp_state 1001` shows the correct members.

### 7. Phone call during radio use
- A and C join the same phone call. A holds the radio key while the call ends.
- Pass: A's radio keeps reaching B and any listener.

## When done
Remove `setr signal_radio_voice_proof 1` from the dev `server.cfg`. Record the results before starting step 2.
