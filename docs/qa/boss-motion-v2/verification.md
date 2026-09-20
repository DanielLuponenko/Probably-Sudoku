# Boss brick motion and visual review

The supplied [reference](user-reference.png) calls for clay blocks, individual landings and brief impact dust. This pass improves both actual blocking bosses, **Gray the Garry** (row) and **Garry the Gray** (box). The other 17 bosses are captured for discussion; their rules and visual designs are unchanged.

## Changes

- Retained the existing authored, grid-aligned red clay brick. No gray replacement boxes are used for the two Garry restrictions.
- Replaced the nearly simultaneous 45ms cadence with 180ms between landings. Each brick accelerates down a straight path, makes a small rigid rebound, and settles on its own blocked blank.
- Fixed contact shadows remain on the board. Warm dust clouds and grains start underneath the brick, expand slightly and disappear after 460ms. The complete nine-cell sequence takes 2.30 seconds.
- Airborne sprites may briefly pass through the preceding row. This intentionally replaces the earlier all-phase per-cell crop, which concealed the visible fall. No horizontal drift is allowed; after contact the brick, rebound, shadow and dust stay inside their own cell. The whole layer is clipped to the board, away from the HUD and hand.
- Fixed a first-entrance bug: a newly mounted board behind a page curl used to consume the landing as already settled. An explicit entrance gate now defers it until reveal. Covered/backgrounded or reduced-motion events still settle without replay when uncovered/resumed.
- No engine, score, save, RNG or hit-target behavior changes.

## Verification

- Build1 focused gate: 50/51 passed. All motion, lifecycle, board-boundary and page-turn tests passed. The gallery's Censor fixture failed because its random censored digit had no printed copy. The shared conserved QA board now places a copy of any absent digit before cloning it for all bosses; this exposes the actual Censor effect without changing the game's roll.
- Visual inspection of build1 caught a ring of dust drawn over the clay face. Build2 places the dust underneath the sprite and at its contact edges.
- Build2 focused gate: 51/51 passed. The independent native review then found thick grid rules crossing over airborne clay. Build3 places the live falling layer above those rules; settled footprints remain contained.
- Final build3 focused gate: **51/51 passed, no failures or skipped tests**. [Summary](focused3-summary.json), [log](focused3.log). Coverage includes separate impact times through the ninth brick, dust clearing, straight transit, strict post-contact containment, board bounds, first-entrance deferral, hidden/reduced-motion cancellation, unchanged restrictions, adjacent playable cells, and page-capture/page-flip lifecycle tests.
- [Final independent native review](native-review.md) passed on iPhone 17 Pro: actual mandatory box-boss Play/page-curl entrance, row-boss End Turn, separate landings, cleared impact dust, corrected layer order, and Settings interruption/return without replay. A released cell remains selectable while a brick-covered blank rejects selection. The review device's original run/profile remain byte-identical. OS Reduce Motion/background behavior is covered by automated state tests; no new native OS-setting pass is claimed.
- Root inspected both overview sheets, full-size Garry/Fog and individual airborne/contact/dust poses, and the before/after grid-crossing storyboards. The interactive gallery was exercised in the browser: full-size viewer, keyboard wraparound, additional Shredder turn-2 state, close/overview return, and aligned image columns.

The gallery uses actual hosted gameplay screenshots on an iPhone 17 Pro canvas, with a shared partially played QA board and populated inventory. All 19 bosses are captured, with additional Shredder turn-2 and urgent Tik Tak states. Capture assertions preserve encoded game bytes and number conservation. These controlled setups are explicitly labeled; they are not a claim that final bosses occur in the first chapter.

## Review artifacts

- [Interactive gallery](boss-gallery.html)
- [Overview 1](boss-overview-1.jpg), [overview 2](boss-overview-2.jpg)
- [Gallery metadata and discussion directions](gallery/boss-gallery-captions.json)
- [Independent native review](native-review.md)

Final candidate: `/tmp/NumberClub-boss-motion-build3.app`. Debug implementation SHA-256: `caf713c2fec1e29527dfc394f501e4c3a527d9b003668deeeee8d052db6f8ab6`. The same code image is installed and launched normally on the user's iPhone 17 Pro (`223A4227-A28E-4939-BB5E-3AAB820EB635`). The saved run/profile were backed up first and remain byte-identical: [comparison](user-simulator-backup/after.json).
