# Music and feedback audio (#19, #69)

The five BGM recordings were supplied by the team in the user's Downloads/BGM
folder on September 14, 2026. They are copied byte-for-byte to `3d_game/audio/bgm/`
with English filenames. No regeneration, editing or new licensing claim is made.
The ordered delivery maps as follows:

| Delivery | Repository file | Use | SHA-256 |
|---|---|---|---|
| 1: pre-game opening | `opening.ogg` | opening | `d11690b83e3df6ade11270cbeb31d9f056011704f6c330c951c4b69ab7a90baa` |
| 2: Stages 1–3 | `chapters_1_3.ogg` | chapters 1 3 | `58c8aa6ba41639c76192879a0358d487fac07437f73bf0c44f9e1564b9c9b8d9` |
| 3: Stage 4 | `otter.ogg` | otter | `07cfc6919105d1dbac7bc0a89bd76d4ac317adfee5c59139db913dc1d793622a` |
| 4: Stage 5 | `storykeeper.ogg` | storykeeper | `ec13687a30a3c53b4dd2e2106c707c131587b12cc979c787e6f9681bb01fca22` |
| 5: Ending | `ending.ogg` | ending | `2a4155b5e7563a1d4ce8fc28bd59b2d57354cd1a315f0fd15b82bbadfd57d50f` |

`GameAudio` is a persistent autoload. Chapters 1–3 share one uninterrupted track;
map visits preserve the current track, and starting a new journey restores the
opening music. Chapter 4, Chapter 5 and either ending select their own recordings.
Music loops and transitions with a short crossfade. Narrator/otter speech reduces
music volume; microphone recording reduces it further and suspends feedback cues.

The Audio control provides Music and Effects levels plus Mute all. The original
River sound switch now mutes the shared master output. Voice retains its independent
control in Talk. Feedback sounds cover buttons, page turns, drawing submission,
ready results, boss release, jumping and quiet footsteps. They are short procedural
PCM sounds authored in `game_audio.gd`; no external SFX generator or credits were
used. Existing River bridge feedback remains in place.

Verification: all five Ogg streams load and loop (99–113 seconds each), route mapping
and same-track reuse pass, cues contain valid samples, and master mute is verified
by `game_audio_smoke.gd`. Narrator and repeat-otter-submit smoke checks pass. Some
headless scene tests still emit engine ObjectDB cleanup warnings. Listen to the
native preview for subjective mix/loop-boundary quality.
