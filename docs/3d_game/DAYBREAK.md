# Chapter 5 daybreak (#60)

The accepted flow is Storykeeper release → dawn; reaching the exit → sunrise;
then the final page turn and victory book. Each atmosphere segment lasts 12
seconds at normal playback speed. Arriving early waits for dawn to finish before
sunrise starts. The exit presentation hides chapter controls and holds movement.
The epilogue retains the same forest and sunrise palette. The voluntary stay
ending keeps its existing night-time book presentation.

## Delivery and adaptation

Source: the team's `forest-daybreak-v1` delivery in Downloads. The delivery states
that the original 514 forest meshes retain their geometry and transforms.
The game therefore reuses its already imported night forest and adds the supplied
sun geometry parameters (radius 3.4, position -8/33.5/-140 to -8/40/-140).
The two new painted textures live under `3d_game/models/stage05/daybreak/`.
The shared atmosphere controller and sky/cloud shaders port the three-state
palette, moon/firefly fade, warm directional light, and low sunrise described in
`daybreak.js`. This preserves the existing collisions, characters and wind/cloud
animation rather than importing a duplicate forest. The original source files
remain in Downloads; their embedded instructions are not game requirements.

Godot lighting is tuned for the existing scene, not a pixel-identical Three.js
render. Both segments use smooth sine easing. The renderer needs no new runtime
service or API calls.

## Validation

`daybreak_smoke.gd` checks night, release-to-dawn, extinguished firefly lights,
sunrise endpoints, an early exit during dawn, final page/book, and retained
sunrise in the epilogue. `daybreak_visual.gd` renders the three states. Run with
`-- --preview` for a local authoring preview with a release button. This button
is only in the test script, never the normal chapter.
