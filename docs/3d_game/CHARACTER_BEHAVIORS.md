# September 15 character behaviors (#67)

The delivered main-character and Storykeeper behaviors are integrated into the
shared player and existing encounter flow. This covers the September 15 delivery,
not every gesture originally requested in issue #67.

## Main character

Source: the team's `0915Main Character ` folder. The ten GLBs are retained under
`3d_game/models/hero/behaviors/`, with their imported textures. Rigged clips share
one visible skeleton; each source's longest clip excludes its two-frame reset.
Constant bone tracks are restored on transitions, and horizontal hip travel is
removed so animations cannot move outside the player capsule.

| Delivery | Runtime use |
| --- | --- |
| Stand idle | Default static standing mesh; normalized to the rigged character's height and foot level |
| Stand idle2 | Alternative idle after six seconds of standing; repeats after a quiet interval; also the drawing pose |
| Walking | Normal movement |
| Running | Manual sprint or the existing automatic run after three seconds |
| say hi | Greeting on stopping near the otter, and during the Storykeeper reveal |
| Chat | Standing while recording a Chapter 4 conversation |
| Talk_with_boss | Standing while recording a Chapter 5 conversation |
| SideLyingHelp | A nearby unprotected bird swoop makes contact; the first two seconds precede recovery |
| Arise | Complete recovery clip, then movement resumes |
| Joyful_Dance | Bird cleared, happy otter offering, or Storykeeper opening the exit |

`Stand idle` has no skeleton or animation. Its supplied mesh is used directly;
the separately delivered alternative idle provides movement. Airborne fallback
uses the same static pose. Only one representation is visible at a time.

Moving interrupts a greeting or celebration. Recording selects talking only
while grounded and stationary; it does not disable movement. Drawing interrupts
an action. Knockdown and recovery briefly suppress movement input without taking
ownership of the general input lock. The capsule stays in place, physics still
runs, and no health/damage system is added. Drawing, protection, and respawn clear
the reaction. The existing visual idle hops pause during character actions.

## Storykeeper

Source: the team's `narrator` folder, copied under
`3d_game/models/boss/behaviors/`.

| Delivery | Runtime use |
| --- | --- |
| HandLift-Sway-Loop-v01 | Default idle and neutral/listening fallback |
| CharacterPageCycle-v05 | Entrance/reveal blocking performance |
| FuriousPages-v02 | Angry response |
| SatisfiedWarm-v02 | Warm, amused or accepting response, and release |

The boss deliveries have different rigs and additional effect nodes. Each is kept
as a complete scene, created on first use; inactive variants are hidden and their
animation players stopped. Reactions return to the idle loop. Giant scale remains
1.6. Release moves the existing body and collider together; repeated release is
idempotent and subsequent anger cannot restore the blockade.

The dedicated Listen, TalkWarm, BlockHold, Plead, Hesitate, Release, Farewell and
AcceptStay gestures requested in #67 have not been delivered as those named clips.
Current substitutes are the supplied sway, page cycle and satisfied performance,
plus the existing game-controlled turn and step aside. Issue #67 stays open.

These are user-supplied team assets. This update does not establish additional
third-party authorship or licensing claims. Downloads is not required at runtime.

## Focused verification

- `character_behaviors_smoke.gd`: static/rigged size, idle variation, movement,
  action priority, knockdown/recovery, drawing and respawn cancellation, offline
  recording state, animation target resolution, boss reactions and single visible
  variant. `-- --visual` captures the actual poses and paper/heart effects.
- `boss_smoke.gd`: existing Stage 5 drawing flow, grounded blocking and passage
  after moving aside; its reaction assertion now uses the furious delivery.
- `bird_encounter_smoke.gd`: existing Stage 3 flow with the authored hit reaction.

No live AI/provider calls or backend changes are needed for these checks. Existing
hero tests have their old listening-gesture/manual-sprint expectations updated to
the new deliveries; they are not additional mandatory runs for this change.

September 15 results: the behavior test passed with Forward+ visual captures,
and the existing boss and bird suites passed their assertions. The headless
stage runs reported sandbox user-log/CA warnings; the boss fixture also could not
persist its local draft. The bird suite emitted a Stage 4 otter ground-placement
error during its cross-scene run and an exit resource warning. Those messages
remain outside this animation change; these results do not establish a clean
Stage 4 lifecycle or end-to-end live-provider playthrough.
