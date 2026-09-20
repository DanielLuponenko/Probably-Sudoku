# Boss expansion verification — 20 September 2026

Implemented all twenty specified bosses: fifteen regular and five final, extending the original nineteen to **39 encounters**. The existing 140-item catalogue remains in place. The implementation brief is retained in [implementation-brief.md](implementation-brief.md).

## Gameplay and persistence

- Original serialized boss IDs remain unchanged. New saved fields default safely when absent; unknown future identities fail decoding instead of substituting another encounter.
- Exact-card seals, FIFO order, packet membership, owed draws, pinned Bookmark order, approved unit types, target increments, allowances and carried post-Mult score are puzzle-owned state.
- Boss selection retains the ordered eligible candidate list and uses only the boss stream. Eligibility tests use copied board/Pool streams and check the remaining play/skip routes. Already-announced bosses stay fixed when inventory changes.
- Rich-loadout eligibility exposed a long synchronous chapter transition. Layout-independent proofs now avoid unnecessary board generation, remaining routes are checked lazily, and the Shop prepares its next chapter on a detached value copy. Only a matching revision/request may commit at the page turn's first frame. Inventory edits, overlays, departure and background cancellation cannot advance or overwrite a newer run.
- Shop advancement is one saved assignment. Hosted production-view tests verify that disappearance after commitment lets the curl finish, while coverage/background before commitment cancels without a save.
- All score changes use the appropriate event, source, point-lot, ordered-Mult or settlement stage. Previews and committed receipts agree. Serial Publisher's Full Clear releases previously earned carry during Keep Filling without awarding new placement points or inventing a Turn bank.
- Embargo preserves legal generated Encore effects; Royalty counts only the consumed outer source. Dry Press suppresses the stated local bonuses while retaining independent non-score effects and finite-use entitlements. Duplicate card/item identities remain separate.
- Historical Collector payouts decode with zero descriptive withheld interest; new payouts show the actual suppressed interest without adding it to the reward.

## Presentation

Physical effects attach to the affected clock, board square, Hand card, item or score receipt. Details and ownership are documented in [visual-implementation.md](visual-implementation.md).

Tik Tak has a stable large countdown and threshold treatments. Fog has two local moving layers below the numerals and retains a static composition when motion is disabled. Its rendering receives no hidden Marker/solution data. Bricks and wet ink use the real committed restricted-square sets and expiry. Hand restrictions remain attached to exact UUIDs; rails and seals occupy the lower tile edge. Current live calculations show Serial carry and Rival fees explicitly.

An independent simulator playtest found and fixed two concrete issues: a brass rail crossed Hand digits, and a sealed card advertised a placement accessibility hint. Both were rechecked natively. It also exercised a real uninterrupted four-minute Tik Tak run through every threshold and expiry, pause/resume, Fog placements/privacy, sequential brick changes, overlapping ink expiry and exact-card Toss behavior. See the [native review](../qa/boss-expansion/native-review.md) for recordings, candidate versions and limits.

The Fog render regression originally captured ImageRenderer's unsupported UIKit-view placeholders. It now mounts the actual board in a UIHostingController, checks visible mist, compares opaque numeral interiors and compares equal public boards with different hidden Marker maps at identical phases.

## Verification results

| Gate | Result |
|---|---|
| Complete engine suite | **480 passed, zero failures**, 309.135 seconds |
| Book/Boss/Obstacle matrix | All **4,212 combinations** exercised |
| Initial complete iOS gate | 838 methods; 16 failing methods identified and addressed |
| Latest affected iOS gate | **156 passed, zero failures** |
| Current-build capture gate | **3 passed, zero failures** |
| Consolidated iOS coverage | **846 methods with latest passing evidence; no unresolved failures** |
| Debug simulator build | Passed; candidate from compile11 |
| Release simulator build | Passed for arm64 and x86_64 |
| Balance scenarios | 40 conserved, saved/resumed scenarios; passed |
| Whitespace/diff check | Passed |

The iOS total is a consolidated audit of the full regression run plus subsequent targeted reruns and added tests; it is not a claim that one later full run contained all 846 methods. [Per-method evidence](../qa/boss-expansion/app-test-audit.json) and [engine audit](../qa/boss-expansion/engine-test-audit.json) retain the exact logs. The targeted reruns include every previously failing method and the new off-main preparation and hosted page-turn checks.

The checked-in [gallery](../qa/boss-expansion/review.html) contains **93 current-build captures** for all twenty additions, including before/after conserved actions at 375×667, 390×844 and 430×932 where applicable, enlarged-text variants, and **41 current-build overview captures** covering every boss plus extra clock/ink states. Hand-specific pairs use 390×844; separate layout tests cover compact and enlarged displays. Capture metadata retains the actual board, IDs, receipts and state.

Primary local results:

- `/tmp/nc-boss-engine-final-14.log`
- `/tmp/NumberClub-boss-full-20260920.xcresult`
- `/tmp/NumberClub-boss-fixes4-20260920.xcresult`
- `/tmp/NumberClub-boss-captures4-20260920.xcresult`
- `/tmp/nc-boss-release-15.log`

## Balance and interaction limits

[The balance report](balance-notes.md) preserves all forty results and exact fixtures. The five-slot fixed build filled the final board but missed Late Courier by 39,740, Page Cutter by 4,130 and Bindery by 21,785 against 512,000. The static three-slot build was much farther below the final target; several Chapter 3 encounters instead fell in one bank. These are tuning signals from a solution-aware policy with fixed items, not human win rates or proof that the bosses are unwinnable. The requested rules and targets were not silently changed.

Native coverage is a bounded interaction sample, not a claim that a person completed all 39 encounters. Engine/state tests cover the remaining combinations. Physical-device haptic/audio quality, Low Power hardware performance and a human campaign balance pass remain unmeasured. The native automation API cannot reliably synthesize a held-touch duration; the existing gesture/state tests cover hold consumption and cancellation, and Fog's hidden inspection/AX paths were checked independently.

## Performance sample and local handoff

A live Fog Time Profiler recording on the isolated iPhone 17 Pro simulator ran for **20.615 seconds**, collecting **1,578 samples**. Main-thread weighted samples totalled **1.353 seconds** (about 6.6% of one core over that interval). Its 250 ms potential-hang table emitted no records. This is sampled CPU evidence on compile8's unchanged live Fog implementation, not a frame-rate, GPU or physical-device measurement. The Animation Hitches template explicitly reported that it is unsupported on this simulator. [Sample details](../qa/boss-expansion/performance-sample.json); raw trace: `/tmp/NumberClub-boss-fog-time-20260920.trace`.

The verified Debug compile11 candidate is installed and open on the user's **iPhone 17 Pro** simulator (`223A4227-A28E-4939-BB5E-3AAB820EB635`). The normal home screen exposes the existing Book's Continue action. No QA scenario replaced that Book. All tracked Application Support and Preferences files were byte-identical after installation and launch, including the active run, profile and discarded-run records.

- Candidate: `/tmp/NumberClub-boss-final-20260920-045339.app`
- App executable library SHA-256: `50509d97210087222749b5f705ff3c949aa461c4f34713953f72ccdce6b0d92c`
- Save/preferences backup: `/tmp/NumberClub-boss-user-backup-20260920-045339`
- Full preservation audit: `/tmp/nc-boss-user-install.json`
- [Handoff screenshot](../qa/boss-expansion/native/user-iphone17pro-handoff.png)

All work remains local. No commits, remote publication or destructive repository operations were performed.
