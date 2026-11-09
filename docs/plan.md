# Radio System for FiveM on pma-voice

## Context
Build a realistic emergency-services radio for the Apex Network FiveM server, inspired by Tommy's Radio, Sonoran Radio, Spartan and Zerio. It keeps pma-voice as the voice engine.

The radio users are QPS, QAS, QFD and RFSQ. The radio connects to Night Shifts MDT (Nights Software, v1).

The server framework is not confirmed. The radio does not depend on a framework. It reads duty and department data from Night Shifts MDT, which handles ESX, Qbox, QBCore or standalone by itself.

First release: handheld radio, talkgroups and zones, permissions, panic, scan, towers that players can jam, signal-quality audio, and an in-game dispatch console.

Working resource name: `signal_radio`. It is an original design, with our own handset art and tones.

## What pma-voice gives us (checked against its source)
- One radio channel per player. The source has a TODO for multi-channel.
- Server: `setPlayerRadio`, `addChannelCheck`. Client: `setRadioChannel`, `addRadioDisableBit`, `removeRadioDisableBit`.
- Client event `pma-voice:radioActive`. Net event `pma-voice:setTalkingOnRadio` carries talk state.
- `registerCustomSubmix` adds audio effects, but `toggleVoice` applies one shared `radio` submix to all talkers.
- Membership is only checked on join, not on transmit.
- `toggleVoice` skips radio volume and effect for talkers within 4 units. Keep this: you hear them in person.

## Night Shifts MDT integration
- Night Shifts gives server and client exports for shift data (start, end, status), departments, ranks, postal lookup, call forwarding (`ForwardCallToMDT`) and shift checks per department. Other export names and parameters: `TODO: confirm in Night Shifts docs`.
- Night Shifts documents no events. To get MDT actions into the radio, add one hook in its unlocked function file (for example `c_functions.lua`) that triggers a `signal_radio` event.
- Night Shifts is partly escrowed. Only the config and function files are editable.
- Night Shifts already has a Leaflet live map with units, calls and panic markers.
- Night Shifts needs oxmysql. The radio itself still uses no database.
- Risk: a Night Shifts update can overwrite the hook. Keep the hook in `patches/night_shifts_hook.md` beside the pma-voice patch, with the steps to reapply it.

## Architecture
The server is the authority. A registry maps each talkgroup to a pma-voice integer channel (range starting at 1001, to avoid clashing with other scripts). The client and UI only request changes.

```
resources/[voice]/pma-voice            patched from patches/signal_radio.patch in the repo
resources/[radio]/signal_radio/
  fxmanifest.lua
  config/    talkgroups.lua, codeplugs.lua, towers.lua, tones.lua
  server/    bridge, registry, permissions, transmit, scan, towers, emergency, dispatch, staff, gps (optional)
  client/    radio, ptt, signal, audio (submixes), towers, emergency
  web/       handset/, dispatch/, shared/, sounds/   (plain JS, no build step)
```

No database. Config lives in Lua files, tower jam timers and callsigns in server KVP, and player preferences in client KVP.

### Permissions
- The codeplug comes from the Night Shifts department and rank, through `server/bridge.lua`.
- A codeplug defines zones, transmit and scan talkgroups, encryption keys, panic behaviour and optional GPS visibility.
- ACE is used only for `radio.admin`, `radio.priority` and `radio.dispatch`.
- Callsign uses `/callsign` and is saved in server KVP.
- Duty comes from the Night Shifts shift state. Ending a shift in the MDT removes the player from restricted talkgroups.
- `canUseRadio(source)` in `server/bridge.lua` returns true only when the player has an active Night Shifts shift, or holds a civilian or business codeplug (TODO: decide which non-emergency users get a radio).
- `canUseJammer(source)` in `server/bridge.lua` denies by default. It allows only players who hold a jammer item (TODO: name the inventory resource once the framework is confirmed).

### pma-voice patch (2 additions, kept minimal)
1. **Listen-only channels.** New server exports `addRadioListener(source, channel, withAudio)` and `removeRadioListener(source, channel)`. When `withAudio` is true, the listener gets talk events and the talker adds the listener through `addVoiceTargets`. When `withAudio` is false, the listener gets talk events only, and the talker does not add the listener as a voice target. `signal_radio` sets `withAudio` to false for keyless listeners on encrypted talkgroups.
2. **Per-talker resolver.** A client export registers a function that `toggleVoice` calls for radio audio. It returns `{ submix, volume }`, or nil to mute that talker.

Everything else uses public exports. Patches between talkgroups need no pma change, because members move to one shared channel.

## Repository
- The project lives in a private GitHub repo. TODO: confirm the repo name and owner (personal account or an Apex Network organisation).
- The repo holds `signal_radio/`, `patches/signal_radio.patch`, `patches/night_shifts_hook.md` and this plan as `docs/plan.md`.
- pma-voice is not committed. The patch file records the pinned pma-voice version.
- Night Shifts files are never committed, because the resource is paid and partly escrowed. `patches/night_shifts_hook.md` holds only our own hook lines and the steps to reapply them.
- `server.cfg`, keys and tokens are never committed. A `.gitignore` covers them.
- Work happens on branches and merges to `main`. Changes reach the dev server before the live server.

## Feature design
- **Talkgroups:** Per-department talkgroups for QPS, QAS, QFD and RFSQ. One interop talkgroup for all four departments. One command talkgroup for senior ranks per department.
- **Push-to-talk:** Keep pma-voice's `+radiotalk` keybind. `addRadioDisableBit` blocks transmit when there is no signal, no radio or the channel is busy.
- **Half-duplex:** The server tracks each channel's active talker. Clients block locally and play a busy tone. If two key up together, the server keeps the first and the loser is cut off. `radio.priority` overrides the block.
- **Scan:** Scan list comes from the codeplug and the server validates it. Primary channel transmits. Scanned channels are heard through listeners at lower volume.
- **Signal:** Client computes the best tower every 1–2 seconds, using distance, jam state and a vehicle bonus. It publishes only tier changes (full, worn, bad, none) in a state bag.
- **Signal audio:** Three custom submixes. The receiver uses the worse of talker and own tier. Tier none mutes receive and blocks transmit. Dispatch consoles ignore signal.
- **Towers:** Replicated from the server. Admin commands place towers and show their radius. Place towers so coverage overlaps. One jammed tower degrades a zone but does not remove all coverage. RFSQ rural areas have coverage from more than one tower.
- **Jammer:** A player walks up to a tower and interacts with it. The player then stays in an animation for 120 seconds before the jammer takes effect. The server records the start time, and on completion checks that 120 seconds have passed and the player is still at the tower. Moving away, dying or cancelling stops the install, and no cooldown starts. Only one player can install on a tower at a time. Once the jammer takes effect, the tower is offline for 5 minutes, then recovers automatically. That tower cannot be jammed again for 30 minutes, counted from when the jammer took effect. All three times are set in `config/towers.lua`. Expiry and cooldown are saved as timestamps, so a server restart does not clear them. Units and dispatch see the tower go offline. `radio.admin` can clear a jam. Every jam is logged (who, which tower, when) and sends an alert to online staff.
- **Fireground channel:** One short-range simplex channel for RFSQ. It works without a tower and ignores signal tiers. Only players within a configurable distance hear each other. The per-talker resolver mutes talkers past that distance. A talker outside the receiver's OneSync scope counts as out of range.
- **Emergency:** Panic with cooldown, tone on the talkgroup and priority for the sender. Man-down alert after a configurable delay.
  - Radio panic also triggers the Night Shifts panic for that player, so the marker shows on the MDT map. TODO: confirm that the panic command can run for a given player from another resource.
  - Night Shifts panic fires the `signal_radio` hook event, so the radio plays the panic tone and gives the sender priority.
  - Man-down sends a call to the MDT through `ForwardCallToMDT`.
- **GPS (optional):** Build this only if the Night Shifts map does not meet the need. Server-side OneSync positions, batched every 2 seconds, sent only to codeplugs with GPS visibility.
- **Handset UI:** Zone and talkgroup selection, talker display, signal bars, member list, scan toggle, panic and draggable position.
- **Dispatch console (`/dispatch`, `radio.dispatch`):** Transmit on a selected talkgroup and monitor others. Tone-outs, talkgroup patching, moving a unit, and a transmission log (who, where, when, with no audio recording).
- **Staff tools:** Admin commands force a player off a channel, clear a stuck talker and dump channel state to the console.
- **Encrypted talkgroups:**
  - A talkgroup in `config/talkgroups.lua` can set `encrypted = true` and a `key` name.
  - A codeplug lists the keys it holds. A player whose codeplug holds the key hears clear audio.
  - A player who can join or scan the talkgroup but has no key hears no voice. The server does not add that player as a voice target. The player gets only the talk start and stop events.
  - A keyless player stays off the talkgroup's pma-voice channel, because pma-voice makes every channel member a voice target. `signal_radio` adds that player with `addRadioListener` and `withAudio` set to false.
  - When a talker on the talkgroup keys up, the keyless client plays a looping "encrypted" noise tone (`web/sounds/encrypted.ogg`, our own file). The loop stops when the talker stops.
  - The keyless handset shows "ENC" and does not show the talker's callsign or name.
  - Keyless players cannot transmit on an encrypted talkgroup.
  - Signal tiers still apply. Tier none stops the noise loop too.
  - Do not use a distortion submix for this. A submix still sends the real voice to the client, and a modified client can remove the submix.
  - Use case: a civilian or criminal scanner (TODO: decide which item or codeplug gives scanner access) hears clear public talkgroups and only noise on encrypted ones.
- **Tones:** Our own files for grant, busy, no-signal, panic, scan and alert. pma mic clicks set to 0 so sounds don't double up.

## Server config
```
setr voice_useNativeAudio true
setr voice_enableSubmix 1
setr voice_enableRadios 1
setr voice_onClickVolume 0
setr voice_offClickVolume 0
```
OneSync must be on.

## Build order
1. **Voice proof:** Apply the pma-voice patch on a separate dev server. Prove listen-only audio and per-talker submixes with test commands.
2. **Core radio:** Registry, codeplugs from Night Shifts, `addChannelCheck` on every mapped channel, PTT, half-duplex, tones.
3. **Handset UI:** Connect NUI to the server state.
4. **Night Shifts integration and emergency:** Shift-based access, panic sync both ways, man-down calls.
5. **Scan:** Listeners and scan lists.
6. **Dispatch console:** Monitoring, patching, tone-outs, unit moves, log.
7. **Towers:** Signal tiers, submix tuning, jammer, saved timers, fireground simplex channel.
8. **Hardening:** Rate limits, player-drop and resource-restart cleanup, staff tools, load test.

## Out of this release
Battery, text messaging, voice bleed to bystanders, browser dispatch, other CAD or MDT systems, and talkaround when all towers are down. The RFSQ fireground channel is the one exception to the talkaround limit. Voice bleed is left out because Mumble audio plays from the talker's position, not from the receiving radio.

## Risks
- **pma-voice updates:** The patch must be reapplied. Keeping it in one patch file makes that a small job.
- **GTA V Enhanced:** FiveM's docs say Mumble is deprecated there, and pma-voice is built on Mumble. This plan targets the standard FiveM build.
- **Security limit:** Server checks stop rule-breaking through events, but a modified client can still touch Mumble targets directly. Treat talkgroup access limits as roleplay rules, not real secrecy. Keyless listeners on encrypted talkgroups get no voice path, and the verification steps check this.
- **Submix tuning:** Effect values need listening tests with real voices.
- **Night Shifts updates:** An update can overwrite the hook in its function file. Reapply it from `patches/night_shifts_hook.md`.
- **Night Shifts exports:** Export names and parameters are not confirmed yet. Confirm them in the docs before step 4 of the build order.
- **pma-voice version:** Pin the pma-voice version that the patch targets. Name who reapplies the patch after an update.
- **Jammer balance:** At about 20 players a night, a jam can stop all emergency comms in a zone. Tune the jam time and tower overlap in play tests.

## Verification
Static checks can run during the build: Lua syntax, and NUI in a browser with mock data. Audio and networking need a real server with at least 3 connected clients (2 can do basic tests).

- Talker A on a channel is heard by B on the same channel, not by C elsewhere.
- C scanning that channel hears A but cannot transmit on it.
- Two players keying together: one transmits and the other gets the busy tone. `radio.priority` overrides.
- Walking from a tower moves through tiers with audible change, then cuts out. Jamming a tower cuts its coverage for 5 minutes, then it recovers by itself.
- The jammer takes effect only after the full 120-second animation. Moving away, dying or cancelling stops it, the tower stays online, and no cooldown starts. A forged completion event before 120 seconds is refused.
- A second jam on that tower is refused until 30 minutes after the first took effect. Other towers can still be jammed. A restart during either timer does not reset it.
- A player whose codeplug does not include a talkgroup cannot join it, including by triggering `pma-voice:setPlayerRadio` directly.
- Panic reaches authorised units and dispatch, and respects the cooldown.
- Dispatch patch: both groups hear each other, and unpatching restores members.
- Dropping a player or restarting `signal_radio` leaves no stale members or disable bits.
- Check client frame time and server tick with the radio idle and during heavy traffic.
- A player with no active Night Shifts shift cannot join a restricted talkgroup. Ending a shift removes the player from those talkgroups.
- The department and rank from Night Shifts give the correct codeplug.
- Radio panic shows a marker on the Night Shifts map. MDT panic plays the panic tone on the radio.
- Man-down creates a call in the MDT.
- Jamming one tower leaves some coverage from an overlapping tower. Staff get a jam alert.
- On the fireground channel, players within range hear each other with no tower, and players out of range do not.
- Staff commands clear a stuck talker and remove a player from a channel.
- On an encrypted talkgroup, a player with the key hears clear audio. A player without the key hears only the noise loop, sees "ENC" with no talker name, and cannot transmit.
- A keyless listener's client receives no voice from the encrypted talkgroup. Confirm this in the Mumble debug output, not only by ear. Keep the two players outside proximity range for this test.
- Run one load test with 10 or more players on the dev server before launch.
- Run all tests on a dev server with the Apex resource list, not on the live server.
- A fresh clone of the repo, plus both patches, installs and starts on the dev server.

## Findings from build step 1
These come from the pma-voice 7.0.1 source. They correct or add to the sections above.

- **4-unit rule:** `currentTargets` is never filled in 7.0.1, so the 4-unit check in `toggleVoice` never applies. The radio effect plays at any distance. The per-talker resolver can return `{ proximity = true }` to restore this rule.
- **Disable bits:** pma-voice ignores radio talk events while a disable bit is set. A lost stop event leaves a talker stuck on radio audio. Step 2 pulses the bit for a busy channel, instead of holding it. Step 2 also calls the `refreshRadioAudio` export after removing any bit.
- **Keyless listeners:** The talker never targets a keyless listener. pma-voice still listens to all in-scope players when a player spectates or uses a scripted camera. That path, or a modified client, can receive a talker's voice. Step 2 must decide how to close this path for keyless players.
- **Patched talkgroups:** A patch moves members onto one shared channel. Patching an encrypted talkgroup with a clear one would expose its voice to the clear group. Step 6 must block that patch.
