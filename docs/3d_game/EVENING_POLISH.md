# Evening encounter polish (#72, partial)

- Chapter 2 automatically presents the completed drawing even if the player has
  left the original interaction area. There is no second E-to-offer action.
- Chapter 3 likewise presents completed protection without a second E press after
  an airborne completion. Chapters 1 and 4 already present generated results.
- Chapter 2's construction camera centers on the protagonist and tracks their
  movement while retaining the sketch/model in frame; dog patrol is not a camera
  subject during construction.
- Unsolved encounter prompts describe goals (distract, protect, cross, connect)
  rather than naming example objects or solution categories. Item descriptions
  may still identify what the player actually drew.
- Chapter 5 uses the new flying-paper model and an in-place release turn. See
  BOSS_INTEGRATION.md. Negative mood results reliably drive the angry animation.

This implements only the six items explicitly selected by the user. Pending UI,
new crouch/turn animation delivery, otter microphone gift, and other teammate
work remain outside this PR; #72 and #63 remain open.
