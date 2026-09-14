# Title and chapter presentation (#81)

The opening uses the supplied **The Tale / We Draw** composition and bundled
Cormorant fonts. It holds the full map for 2.5 seconds, then zooms toward Chapter I
for 1.65 seconds while the title shrinks into the upper-left corner and the curved
chapter paper, live text, and painted Play button rise together. The traveler
walks from below the paper to the first marker in 1.2 seconds. Play becomes
available after arrival; entering a chapter still requires explicit confirmation.

The title uses depth-tested Label3D text. The mountains genuinely occlude its
opening placement. The smaller corner title moves nearer the camera during zoom and uses pale ink
on the night map.
Chapter II–V retain route travel and the day/evening/night palette changes before
showing the same paper entrance. Map browsing still returns to the existing
chapter instance and uses **Return** on its card.

| Chapter | Supplied title |
| --- | --- |
| I | The Other Side |
| II | A Growling Welcome |
| III | Trouble Overhead |
| IV | A Friend by the Water |
| V | Just One More Page |

The epilogue opens with the supplied **The End / Thank You for Playing / by Four
Otters** artwork over the sunrise environment. A matching paper footer holds
**Your journey**, **Play again**, and **Stay a while**. Your journey opens the
existing keepsake spread, retaining the session's actual chapter and sketch
counts. Back returns to The End. Both sets of replay/exploration controls use the
existing ending signals and are disabled during transitions.

## Assets and credits

Runtime assets live in `3d_game/ui/title/`. The paper and ending art are the user's
Downloads exports (`Ellipse 1.svg` and `Property 1=End.svg`). `play_paper.svg` is
derived from `Frame 4.svg`, removing outlined lettering so the real Godot button
can display Play or Return. Chapter titles are live labels matching the supplied
chapter composites. The source Downloads files are unchanged.

Cormorant regular and italic variable fonts are from the official Google Fonts
repository: <https://github.com/google/fonts/tree/main/ofl/cormorant>.
Copyright Christian Thalmann; distributed under the SIL Open Font License 1.1.
The complete license is in [Cormorant-OFL.txt](assets/title/Cormorant-OFL.txt).

## Verification

Offline Godot 4.7.2 checks cover the real-time opening hold, delayed Play activation,
all five chapter cards, map scene retention, chapter transition boundaries,
session recap, replay, and daybreak. `title_ui_smoke.gd` adds focused presentation
and ending-action coverage; existing journey tests retain their gameplay checks.
The overworld test checks settled arrival invariants instead of requiring a sample
inside a transient arrival phase at 100x test speed. The journal test waits for
the hero entrance and actual journey completion before reading the ending recap.

Native Forward+ visual review covers the opening, all five cards, The End, the
keepsake spread, and a smaller window. Selected captures are under
`assets/title/`. No paid AI calls are used by these checks.

Known baseline diagnostics: the Chapter IV otter reports “Otter greeting position
needs solid ground” during the accelerated multi-chapter headless test. The same
message was reproduced with main's original overworld code and original flow test
at `47249a9`; the unmodified baseline also has the transient-arrival test failure.
This title change does not modify otter placement. macOS headless runs also emit
the existing certificate lookup and shutdown ObjectDB diagnostics.

The pending menu resume/default-volume change remains in PR #85. This PR does not
close #72 or merge that separate work.
