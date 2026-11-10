# Radio System for FiveM on pma-voice

## Context
Build a realistic emergency-services radio for the Apex Network FiveM server, inspired by Tommy's Radio, Sonoran Radio, Spartan and Zerio. It keeps pma-voice as the voice engine.

The radio users are QPS, QAS, QFD, RFSQ and civilians. The radio connects to Night Shifts MDT (Nights Software, v1).

The server framework is not confirmed. The radio does not depend on a framework. It reads duty and department data from Night Shifts MDT, which handles ESX, Qbox, QBCore or standalone by itself.

First release: handheld radio, talkgroups and zones, permissions, civilian radios, encrypted talkgroups, panic, scan, towers that players can sabotage, signal-quality audio, and an in-game dispatch console.

Working resource name: `signal_radio`. The handsets use product photos of the Motorola APX 2000, Motorola APX 8000XE and Baofeng UV-5R with clickable zones, chosen for this private server. The handset generates its own tones. Replace the photos before any sale or public release.

## What pma-voice gives us (checked against its source)
- One radio channel per player. The source has a TODO for multi-channel.
- Server: `setPlayerRadio`, `addChannelCheck`. Client: `setRadioChannel`, `addRadioDisableBit`, `removeRadioDisableBit`.
- Client event `pma-voice:radioActive`. Net event `pma-voice:setTalkingOnRadio` carries talk state.
- `registerCustomSubmix` adds audio effects, but `toggleVoice` applies one shared `radio` submix to all talkers.
- Membership is only checked on join, not on transmit.
- `toggleVoice` has a 4-unit check, but version 7.0.1 never fills the table it reads. The radio effect plays at any distance.

## Night Shifts MDT integration
- The radio uses only the exports in `docs/EXPOSED_EXPORTS.md`, the guide that ships with Night Shifts. The guide treats every other export as unsupported.
- The resource folder must be named `night_shifts_mdt`. Calls use the colon form: `exports['night_shifts_mdt']:ExportName(...)`.
- `GetUserShiftData(source)` gives the shift state, department and callsign, plus postal, street and zone.
- The guide documents no event for a shift, status or panic change. The radio reads every player's shift each 5 seconds. No Night Shifts file changes, so an update cannot overwrite a hook.
- `config/night_shifts.lua` maps each Night Shifts department ID to a codeplug. The `radio_ns_dump` console command prints the IDs and one player's shift.
- A player on a department with no mapping gets the civilian radio.
- Senior ranks are not decided. A shift does not give the command channel yet. TODO: confirm in Night Shifts docs: the rank field in `GetUserShiftData`.
- The radio keeps working when Night Shifts is stopped or a read fails. It keeps each player's current radio until a read succeeds.
- Night Shifts already has a Leaflet live map with units, calls and panic markers.
- Night Shifts needs oxmysql. The radio itself still uses no database.

## Architecture
The server is the authority. A registry maps each talkgroup to a pma-voice integer channel (range starting at 1001, to avoid clashing with other scripts). A tuned frequency uses its value in kHz as the channel, for example 476425. The client and UI only request changes.

```
resources/[voice]/pma-voice            patched from patches/signal_radio.patch in the repo
resources/[radio]/signal_radio/
  fxmanifest.lua
  config/    talkgroups.lua, codeplugs.lua, towers.lua, night_shifts.lua
  server/    bridge, registry, permissions, radio, transmit, towers, bleed, voice_proof
  client/    radio, ptt, audio, signal, towers, voice_proof
  web/       handset/ with skins/   (plain JS, no build step)
```

Later steps add `web/dispatch/`, staff tools and optional GPS. `voice_proof` holds dev-only test commands. `web/handset/compare.html` previews the skins in a browser and does not ship to the game.

No database. Config lives in Lua files. Callsigns, scan choices, the tower list and tower sabotage timers live in server KVP. Handset position and volume live in client KVP.

### Permissions
- The codeplug comes from the Night Shifts department, through `server/bridge.lua`. On a dev server, a `/radio_dev` profile takes priority over a shift.
- A codeplug defines the skin, zones and starting scan list. Later steps add panic behaviour and optional GPS visibility.
- ACE is used only for `radio.admin`, `radio.priority` and `radio.dispatch`.
- On shift, the callsign comes from the MDT and `/callsign` is blocked. Off shift, `/callsign` sets the callsign and saves it in server KVP. A shift with no MDT callsign also uses the saved one.
- Duty comes from the Night Shifts shift state. Starting a shift, changing department or ending a shift turns the radio off and rebuilds it within 5 seconds. Ending a shift removes the player from restricted talkgroups.
- `canUseRadio(source)` in `server/bridge.lua` returns true for every player. A player with no active shift gets the civilian radio (see Civilian use).
- `canSabotage(source)` in `server/bridge.lua` returns true. Sabotage needs no item, and any player can start it at a tower.

### pma-voice patch (2 additions, kept minimal)
1. **Listen-only channels.** New server exports `addRadioListener(source, channel, withAudio)` and `removeRadioListener(source, channel)`. When `withAudio` is true, the listener gets talk events and the talker adds the listener through `addVoiceTargets`. When `withAudio` is false, the listener gets talk events only, and the talker does not add the listener as a voice target. `signal_radio` sets `withAudio` to false for keyless listeners on encrypted talkgroups.
2. **Per-talker resolver.** A client export registers a function that `toggleVoice` calls for radio audio. It returns `{ submix, volume }`, `{ proximity = true }` for normal voice, or nil to mute that talker. The `refreshRadioAudio` export reapplies audio for every talker.

The patch also corrects four pma-voice behaviours that the radio depends on: releasing the radio key when the channel drops to 0, keeping phone call audio when a radio talker stops, respecting disable bits during an audio refresh, and clearing voice targets when members leave during a transmission.

Everything else uses public exports. Patches between talkgroups need no pma change, because members move to one shared channel.

## Civilian use
Civilians can use the radio as well as the four emergency departments. A civilian does not need a Night Shifts shift.

- **Civilian radios:** Every civilian can get a radio. A player with no active Night Shifts shift uses a civilian radio.
- **Frequencies:** Civilians have no talkgroups, zones or named channels. A civilian tunes one real frequency at a time, shown in MHz, for example 476.425. The radio accepts 136.000 to 174.000 and 400.000 to 520.000 MHz.
- **Tuning:** A civilian types six digits on the radio's number keys or the keyboard. The radio tunes on the sixth digit. The up and down keys step by 0.025 MHz. Civilians on the same frequency talk to each other in clear audio.
- **Emergency talkgroups:** Every emergency talkgroup is encrypted. Emergency radios hold one shared key, and can switch between each other's talkgroups to communicate. Command talkgroups stay senior-only.
- **No scanners:** Civilians have no scan or scanner access. Scan is for emergency radios only.
- **Why encryption exists:** Every civilian can own a radio. Emergency services need traffic that a civilian radio cannot hear.
- **What a civilian gets on an emergency frequency:** Each emergency talkgroup has a frequency in `config/talkgroups.lua`. A civilian who tunes to one hears only noise during traffic. The handset shows "ENC" and hides the talker. The civilian cannot transmit there. The server sends a keyless radio no voice. A civilian standing beside an emergency radio can still overhear it through speaker bleed.
- **Signal and sabotage:** Signal tiers, tower sabotage and direct radio affect civilian radios too.
- **Panic:** The radio type decides whether a radio has a panic button. A radio type without an emergency button has no panic.
- **Other limits:** Civilians have no dispatch access, because the console needs `radio.dispatch`.
- **Handset:** Civilian radios use the Baofeng UV-5R skin. It has no emergency button, so civilian radios have no panic.
- **UV-5R keys:** MENU opens the units on the current frequency, and selects the highlighted row in the band list. BAND opens a VHF or UHF choice, because civilians have no zones. EXIT returns to the channel screen. The `*` key deletes a digit. VFO/MR and A/B are not clickable. The square below VFO/MR lights only while transmitting.
- **Before civilian radios go live:** Set `voice_disableAutomaticListenerOnCamera`, which closes the scripted camera path. Decide how to handle spectator mode, which can still hear encrypted voice. Step 6 must block patching an encrypted talkgroup with a clear one.

## Repository
- The project lives in the private GitHub repo `corpsecopytv/signal_radio`.
- The repo holds `signal_radio/`, `patches/signal_radio.patch`, this plan as `docs/plan.md`, and the test scripts in `docs/`.
- pma-voice is not committed. The patch file records the pinned pma-voice version.
- Night Shifts files are never committed, because the resource is paid and partly escrowed. This includes its export guide.
- `server.cfg`, keys and tokens are never committed. A `.gitignore` covers them.
- Work happens on branches and merges to `main`. Changes reach the dev server before the live server. TODO: create `main`. The repo currently has only `feat/voice-proof`.

## Feature design
- **Talkgroups:** Per-department talkgroups for QPS, QAS, QFD and RFSQ. One interop talkgroup for all four departments. One command talkgroup for senior ranks per department. All are encrypted with one shared key, and every emergency radio can switch between the departments' talkgroups.
- **Push-to-talk:** Keep pma-voice's `+radiotalk` keybind. The binding also works while the radio is open, because the handset uses `SetNuiFocusKeepInput` and blocks other game controls. Other resources' key bindings can also fire while it is open. The handset's side button also transmits. `addRadioDisableBit` cuts a transmission when the channel is busy, as a short pulse. A radio with no tower signal can still transmit, and only radios in direct range hear it.
- **Half-duplex:** The server tracks each channel's active talker. Clients block locally and play a busy tone. If two key up together, the server keeps the first and the loser is cut off. `radio.priority` overrides the block.
- **Scan:** Each player chooses what their radio scans, from any talkgroup their radio can use. The codeplug sets the starting list. The server validates each choice and saves it per player and department. The Scan key opens a list with an on or off row, then every talkgroup with a tick. Primary channel transmits. Scanned channels are heard through listeners at 60% volume, all at once. Scan starts off after a reconnect.
- **Signal:** Client computes the best tower every 1.5 seconds, using distance, sabotage state and a vehicle bonus. It sends only tier changes (full, worn, bad, none) to the server, which passes the talker's tier to receivers with each transmission. With no towers configured, every radio has full signal.
- **Signal audio:** Five custom submixes: near, full, worn, bad and bleed. The tower path uses the worse of the talker's and receiver's tower tiers. Dispatch consoles ignore signal.
- **Direct radio:** Every radio also works like a small tower for other radios on the same talkgroup or frequency. Direct range is 500 metres, the same as the fireground channel, set in `config/towers.lua`. It uses the same quality rules as a tower: 1.0 beside the talker, 0.0 at the edge of the range.
  - A receiver uses whichever path is better, tower or direct.
  - Within 100 metres, the talker uses the clearest audio.
  - With neither path, the receiver hears nothing.
  - A radio with no tower signal shows 0 bars and "Direct". It can still transmit and receive within direct range.
  - Sabotage takes a tower offline, but does not stop direct radio.
  - Direct radio applies to emergency and civilian radios, in zone mode and frequency mode.
  - A talker on direct radio only does not make the channel busy for radios that cannot hear them. The game streams players up to about 424 metres away, so the server supplies the distance beyond 300 metres.
- **Speaker bleed:** People close to a radio can hear its speaker while it receives traffic.
  - The bleed range is 10 metres, set in `config/towers.lua`. Volume falls with distance from the nearest radio that is receiving.
  - Audio uses a muffled submix, so it sounds like a nearby speaker.
  - A radio only bleeds what it can receive. A radio that is off, or out of range of the talker, does not bleed.
  - A radio does not bleed while it is the one transmitting.
  - Scanned traffic bleeds too.
  - A player who already hears that talkgroup on their own radio does not hear it twice.
  - A radio tuned to that encrypted frequency stays on noise only. pma-voice allows one listen state per channel.
  - No pma-voice change is needed. During traffic, the server adds nearby players as audio listeners on the channel, and removes them when they move away or the traffic ends.
  - Mumble plays the voice from the talker, not from the radio. Volume and muffling stand in for the radio's position.
  - Speaker bleed includes encrypted talkgroups, because the receiving radio has already decoded the audio. Anyone beside that radio can overhear it.
- **Towers:** Replicated from the server. `/radio_tower` adds, removes, resizes, clears and lists towers, and needs `radio.admin`. `/radio_tower_debug` shows each radius on the map. `config/towers.lua` holds nine placeholder sites. TODO: replace them with real sites. Place towers so coverage overlaps. One sabotaged tower degrades a zone but does not remove all coverage. RFSQ rural areas have coverage from more than one tower.
- **Sabotage:** Sabotage needs no item. Any player can walk up to a tower and press E at its marker. The player then stays in an animation for 120 seconds before the sabotage takes effect. The server records the start time, and on completion checks that 120 seconds have passed and the player is still at the tower. Moving away, dying or cancelling stops the sabotage, and no cooldown starts. Only one player can sabotage a tower at a time. Once the sabotage takes effect, the tower is offline for 5 minutes, then recovers automatically. That tower cannot be sabotaged again for 30 minutes, counted from when the sabotage took effect. All three times are set in `config/towers.lua`. Expiry and cooldown are saved as timestamps, so a server restart does not clear them. Units and dispatch see the tower go offline. `radio.admin` can clear a sabotage. Every sabotage is logged (who, which tower, when) and sends an alert to online staff.
- **Fireground channel:** One short-range simplex talkgroup in the RFSQ zone, with a 500 metre range set in `config/talkgroups.lua`. It works without a tower and ignores signal tiers. It has the same 500 metre range as direct radio, but keeps full quality across that range. Only players within a configurable distance hear each other. The per-talker resolver mutes talkers past that distance, using the server's distance beyond the game's streaming range.
- **Emergency:** Panic with cooldown, tone on the talkgroup and priority for the sender. Man-down alert after a configurable delay.
  - Radio panic sets that player's MDT status through `UpdateShiftStatusByBindingByServerId(source, 'panic', callback)`. TODO: confirm in Night Shifts docs: whether this status puts a marker on the MDT map.
  - The 5 second shift check watches for a change to panic status. The radio then plays the panic tone on the player's channel and gives the sender priority. The panic cooldown stops a radio panic from playing twice. TODO: confirm in Night Shifts docs: the `statusCode` field and the code that means panic.
  - A radio that is off, or on no channel, plays nothing for an MDT panic.
  - Man-down applies to an emergency radio that is on. After 30 seconds dead, the radio sends one call through `ForwardCallToMDT`, with call type `Panic`, sent to police and ambulance. The server refuses the alert if the player is alive, and allows one call each 60 seconds. Both times are set in `config/night_shifts.lua`.
  - A man-down call goes to the MDT only. It plays no tone on the radio.
- **GPS (optional):** Build this only if the Night Shifts map does not meet the need. Server-side OneSync positions, batched every 2 seconds, sent only to codeplugs with GPS visibility.
- **Handset UI:** Zone and talkgroup selection, talker display, signal bars, member list, scan list, panic and draggable position. Each skin is a photo with a live screen and clickable zones over the real controls. Signal bars show the current tier. The radio's up and down keys move a highlight through any list. Select or Enter chooses the highlighted row. A status strip stays on screen when the radio is put away.
- **Skins:** QPS and QAS use the APX 2000. QFD and RFSQ use the APX 8000XE in hi-vis. Civilians use the UV-5R. Each codeplug sets its skin in `config/codeplugs.lua`.
- **Dispatch console (`/dispatch`, `radio.dispatch`):** Transmit on a selected talkgroup and monitor others. Tone-outs, talkgroup patching, moving a unit, and a transmission log (who, where, when, with no audio recording).
- **Emergency frequency mode:** Every emergency radio has every zone. The Zone list also has a Frequency option. In frequency mode, an emergency radio tunes by frequency like a civilian radio, and can talk to civilians on a clear frequency. Dialling an emergency frequency joins that talkgroup with clear audio. A command frequency stays encrypted for radios that are not senior. Scan pauses in frequency mode. Choosing a zone returns the radio to zone mode.
- **Staff tools:** Admin commands force a player off a channel, clear a stuck talker and dump channel state to the console.
- **Encrypted talkgroups:**
  - Purpose: Encryption keeps emergency services traffic private from civilian radios (see Civilian use).
  - Every talkgroup in `config/talkgroups.lua` is encrypted. A radio that can use a talkgroup holds its key and hears clear audio.
  - A radio that tunes to a talkgroup's frequency without access hears no voice. The server does not add that player as a voice target. The player gets only channel activity, with no talker identity.
  - A keyless player stays off the talkgroup's pma-voice channel, because pma-voice makes every channel member a voice target. `signal_radio` adds that player with `addRadioListener` and `withAudio` set to false.
  - When a talker on the talkgroup keys up, the keyless client plays a looping "encrypted" noise, generated in the handset. The loop stops when the talker stops.
  - The keyless handset shows "ENC" and does not show the talker's callsign or name.
  - Keyless players cannot transmit on an encrypted talkgroup.
  - A keyless radio plays noise wherever it has tower signal, whatever the talker's range.
  - Signal tiers still apply. Tier none stops the noise loop too, because a keyless radio gets no talker position to use direct radio.
  - Do not use a distortion submix for this. A submix still sends the real voice to the client, and a modified client can remove the submix.
  - Use case: a civilian who tunes to an emergency frequency hears only noise.
- **Tones:** The handset generates its tones for grant, release, busy, power, receive and panic. pma mic clicks set to 0 so sounds don't double up.

## Server config
```
setr voice_useNativeAudio true
setr voice_enableSubmix 1
setr voice_enableRadios 1
setr voice_onClickVolume 0
setr voice_offClickVolume 0
setr voice_disableAutomaticListenerOnCamera 1
```
OneSync must be on. The dev server also uses `setr signal_radio_dev_profiles 1` and `setr signal_radio_voice_proof 1`. Never set these on the live server.

## Build order
1. **Voice proof:** Apply the pma-voice patch on a separate dev server. Prove listen-only audio and per-talker submixes with test commands.
2. **Core radio:** Registry, codeplugs from Night Shifts, `addChannelCheck` on every mapped channel, PTT, half-duplex, tones.
3. **Handset UI:** Connect NUI to the server state.
4. **Night Shifts integration and emergency:** Shift-based access, panic sync both ways, man-down calls.
5. **Scan, civilian radios and encryption:** Listeners, scan lists, civilian codeplugs, encrypted talkgroups and the noise loop.
6. **Dispatch console:** Monitoring, patching, tone-outs, unit moves, log.
7. **Towers:** Signal tiers, submix tuning, sabotage, saved timers, fireground simplex channel.
8. **Direct radio and speaker bleed:** Radio-to-radio range, the Direct indicator, bleed listeners and the muffled submix.
9. **Hardening:** Rate limits, player-drop and resource-restart cleanup, staff tools, load test.

## Build status
Status at 2026-11-10.

| Step | Status |
| --- | --- |
| 1. Voice proof | Done. All seven in-game tests passed. |
| 2. Core radio | Working in-game. Dev profiles stand in for Night Shifts. |
| 3. Handset UI | Working in-game. |
| 4. Night Shifts integration and emergency | Built and logic-tested. Waiting on the in-game test in `docs/test_night_shifts.md`. Senior ranks are not decided. |
| 5. Scan, civilian radios and encryption | Working in-game. Spectator mode is still open. |
| 6. Dispatch console | Not started. |
| 7. Towers | Working in-game. Built ahead of steps 4 and 6. |
| 8. Direct radio and speaker bleed | Built. Waiting on the in-game test in `docs/test_towers.md`. |
| 9. Hardening | Not started. |

Emergency frequency mode, all-zone access and chosen scan lists are built as part of steps 2, 3 and 5. The in-game test for this build is `docs/test_core_radio.md`.

## Out of this release
Battery, text messaging, browser dispatch and other CAD or MDT systems.

## Risks
- **pma-voice updates:** The patch must be reapplied. Keeping it in one patch file makes that a small job.
- **GTA V Enhanced:** FiveM's docs say Mumble is deprecated there, and pma-voice is built on Mumble. This plan targets the standard FiveM build.
- **Security limit:** Server checks stop rule-breaking through events, but a modified client can still touch Mumble targets directly. Treat talkgroup access limits as roleplay rules, not real secrecy. Keyless radios on encrypted talkgroups get no voice path, and the verification steps check this.
- **Submix tuning:** Effect values need listening tests with real voices.
- **Speaker bleed position:** Bleed cannot play from the radio's real position. It may sound flat, or wrong when the talker is also close by.
- **Speaker bleed load:** The server checks positions around every receiving radio during traffic. Measure this in the load test.
- **Speaker bleed and encryption:** Bleed includes encrypted talkgroups, so a civilian within 10 metres of an emergency radio can hear that traffic. This is intended.
- **Night Shifts updates:** An update can change an export. Compare `docs/EXPOSED_EXPORTS.md` after each update, and rerun `docs/test_night_shifts.md`.
- **Night Shifts fields:** The shipped guide does not list the rank or status field in `GetUserShiftData`. MDT-to-radio panic depends on the status field. The first in-game test confirms it.
- **Shift check delay:** A shift change or MDT panic reaches the radio up to 5 seconds later.
- **Man-down and death scripts:** The alert needs the game's dead state. A script that respawns players before the delay stops the alert. A script that keeps downed players alive also stops it.
- **pma-voice version:** Pin the pma-voice version that the patch targets. Name who reapplies the patch after an update.
- **Sabotage balance:** At about 20 players a night, a sabotage can stop long-range emergency comms in a zone. Direct radio still works up close. Tune the sabotage time and tower overlap in play tests.

## Verification
Static checks can run during the build: Lua syntax, and NUI in a browser with mock data. Audio and networking need a real server. One person can run most tests with two clients on one PC, using the steps in `docs/test_core_radio.md`. Overlap and load tests need more real players.

- Talker A on a channel is heard by B on the same channel, not by C elsewhere.
- C scanning that channel hears A but cannot transmit on it.
- Two players keying together: one transmits and the other gets the busy tone. `radio.priority` overrides.
- Walking from a tower moves through tiers with audible change, then loses tower signal. Sabotaging a tower cuts its coverage for 5 minutes, then it recovers by itself.
- Sabotage takes effect only after the full 120-second animation. Moving away, dying or cancelling stops it, the tower stays online, and no cooldown starts. A forged completion event before 120 seconds is refused.
- A second sabotage on that tower is refused until 30 minutes after the first took effect. Other towers can still be sabotaged. A restart during either timer does not reset it.
- A player whose codeplug does not include a talkgroup cannot join it, including by triggering `pma-voice:setPlayerRadio` directly.
- Panic reaches authorised units and dispatch, and respects the cooldown.
- Dispatch patch: both groups hear each other, and unpatching restores members.
- Dropping a player or restarting `signal_radio` leaves no stale members or disable bits.
- Check client frame time and server tick with the radio idle and during heavy traffic.
- A player with no active Night Shifts shift cannot join a restricted talkgroup. Ending a shift removes the player from those talkgroups.
- The department and rank from Night Shifts give the correct codeplug.
- Radio panic sets the player's MDT status to panic. Check whether it also shows a marker on the Night Shifts map. MDT panic plays the panic tone on the radio.
- Man-down creates a `Panic` call for police and ambulance in the MDT. A radio that is off, or a civilian radio, sends no call.
- On shift, the radio shows the MDT callsign and `/callsign` is blocked.
- The radio keeps working when Night Shifts stops.
- Sabotaging one tower leaves some coverage from an overlapping tower. Staff get a sabotage alert.
- On the fireground channel, players within range hear each other with no tower, and players out of range do not.
- Staff commands clear a stuck talker and remove a player from a channel.
- On an encrypted talkgroup, a player with the key hears clear audio. A player without the key hears only the noise loop, sees "ENC" with no talker name, and cannot transmit.
- A keyless listener's client receives no voice from the encrypted talkgroup. Confirm this in the Mumble debug output, not only by ear. Keep the two players outside proximity range for this test.
- Run one load test with 10 or more players on the dev server before launch.
- Run all tests on a dev server with the Apex resource list, not on the live server.
- A fresh clone of the repo, plus both patches, installs and starts on the dev server.
- A player with no Night Shifts shift gets a civilian radio, and tunes one frequency at a time.
- Typing six digits on the radio keys or the keyboard tunes that frequency. A frequency out of band is refused.
- Two civilians on the same frequency can talk to each other.
- A civilian who tunes to an emergency frequency hears only noise, sees "ENC" and cannot transmit.
- A civilian radio has no scan option.
- Every emergency radio lists every zone. Junior radios do not list command talkgroups.
- A player can add and remove talkgroups from their scan list, and the choice survives a reconnect.
- An emergency radio in frequency mode can talk to a civilian on the same clear frequency.
- An emergency radio in frequency mode that dials an emergency frequency hears it clearly. A junior radio on a command frequency hears only noise.
- Choosing a zone returns an emergency radio from frequency mode, and scan resumes.
- An emergency radio from one department can switch to another department's talkgroup and hear it clearly.
- A radio type without an emergency button cannot send a panic.
- Two radios with no tower signal can talk within 500 metres, with quality falling as they separate. They cannot talk past 500 metres.
- A radio with tower signal uses direct radio when it sounds better than the tower path.
- A radio with no tower signal shows 0 bars and "Direct".
- Direct radio works while a tower is sabotaged, for emergency and civilian radios.
- A player within 10 metres of a receiving radio hears muffled speaker audio. It fades with distance and stops past 10 metres.
- A civilian within 10 metres of an emergency radio hears encrypted traffic through speaker bleed, but still hears only noise on their own radio.
- A radio that is off, transmitting, or out of range of the talker does not bleed.
- A player in a different routing bucket does not hear bleed.
- Holding the radio key while the radio turns off or changes channel releases the transmission.
- A player already on the talkgroup does not hear bleed as well.
- Bleed listeners are removed when the traffic ends, when the player walks away, and when the resource restarts.

## Findings from build step 1
These come from the pma-voice 7.0.1 source. They correct or add to the sections above.

- **4-unit rule:** `currentTargets` is never filled in 7.0.1, so the 4-unit check in `toggleVoice` never applies. The radio effect plays at any distance. The per-talker resolver can return `{ proximity = true }` to restore this rule.
- **Disable bits:** pma-voice ignores radio talk events while a disable bit is set. A lost stop event leaves a talker stuck on radio audio. The radio pulses the bit for a busy channel, instead of holding it. It also calls the `refreshRadioAudio` export after removing the bit.
- **Keyless listeners:** The talker never targets a keyless listener. pma-voice still listens to all in-scope players when a player spectates or uses a scripted camera. That path, or a modified client, can receive a talker's voice. `voice_disableAutomaticListenerOnCamera` closes the scripted camera path. Spectator mode and modified clients remain open.
- **Patched talkgroups:** A patch moves members onto one shared channel. Patching an encrypted talkgroup with a clear one would expose its voice to the clear group. Step 6 must block that patch.
