# Focused game verification

Run the test for the behavior being changed. Do not run every script in
`3d_game/tests` for routine edits, a rebase, or a game launch. Keep full output in
a temporary log and report the result plus actionable failures. Repeat a check
only after a relevant edit, a failure, or a remaining concern.

Each stage retains its own encounter coverage:

| Stage | Main test | Behavior covered |
| --- | --- | --- |
| 1: River | `river_smoke.gd` | Drawing/input, request failures, bridge construction, crossing and reset |
| 2: Dog | `dog_encounter_smoke.gd` | Patrol and gate, unsuitable offerings, food/toy outcomes and progression |
| 3: Bird | `bird_encounter_smoke.gd` | Submission including sky/unsafe-ground fallback, retry/cancel, protection, departure and progression |
| 4: Otter | `otter_greeting_smoke.gd` | Greeting and heart visibility, repeat submission through Confirm, AI happiness and microphone gift/unlock |
| 5: Storykeeper | `boss_smoke.gd` | Drawing-to-model completion, placement, canceled/stale results, dialogue continuity, boss collision and passage after clearing |

For example, run Stage 5 from the repository root:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path 3d_game --script res://tests/boss_smoke.gd > /private/tmp/paws-boss-test.log 2>&1
```

Keep the following additional checks focused on their distinct responsibilities:

- `dog_presentation_smoke.gd`: reveal timing, automatic offering after walking
  away, cancellation during reveal, and camera/control restoration.
- `offering_settle_smoke.gd`: real mesh collision, gravity and resting orientation,
  player contact, AI mass and fixed/floating placement. Run for physics changes.
- `desktop_generation_smoke.gd`, `draft_retention_smoke.gd`, and narrator/voice
  tests: worker boundaries, saved drafts, and conversation lifecycle respectively.
- `encounter_playtest_smoke.gd`: actual desktop adapter completion for an
  unsuitable Stage 3 model followed by a successful retry.
- `stage_entrance_smoke.gd` and the exit/transition tests: grounded walk-in,
  input ownership and scene replacement. Run when navigation changes.
- UI, audio, ending and rendering checks: run only for changes to those systems.
  Visual/preview scripts are manual inspection tools, not an automatic suite.

## Removed coverage and consolidation

Removed 15 standalone smoke scripts (49 reduced to 34). Automatic offering,
Stage 3 submission fallback and protection departure, Stage 4 repeat submission,
and Stage 5 object generation now use existing stage test setups.

Retired the separate woodland, wind hill, sunset cove and moonlit forest asset
audits, plus bird arrival/framing, dog framing, generation-mist and diagnostics
micro-tests. Grounded entrances, encounter outcomes, physical object behavior and
stage exits retain behavioral checks. Exact mesh counts, shader constants,
animation asset inventories, pixel framing and diagnostic log formatting are no
longer standalone automated contracts; inspect visuals when those assets change.
The old dog-framing expectation that a dog cannot displace a physical offering
also conflicts with the current collidable-object behavior.

Backend tests remain unchanged: their provider contracts, validation and failure
handling cover a separate boundary. Repository instructions require the full
offline backend suite after backend changes. No backend suite is needed for this
game-test-only consolidation, and no paid AI calls are needed.
