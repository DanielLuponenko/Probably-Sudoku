# Tutorial and Settings native review

## Baseline

Audited the existing app on isolated **Book Playtest A — iPhone 17 Pro**, iOS 26.3 (D04D3836), at its unchanged normal text size. Candidate: `/tmp/NumberClub-game-motion-candidate.app`. Used the actual Settings entry and Replay tutorial, with a non-persisting QA puzzle. The user's simulator and physical devices were not used.

Original Application Support and Preferences were backed up to `/tmp/NumberClub-tutorial-native-original-D04`; its manifest contains eight files. No OS settings were changed.

- **Volume controls:** at zero, the rails are almost invisible against the paper, leaving disconnected white thumbs. See `baseline-settings.png`. A native accessibility `setValue` moved a thumb but did not update the descriptive value; that method can bypass UIControl events, so this is not evidence of a product persistence bug. Direct CUA drag was inconclusive.
- **Practice presentation:** the miniature flat board differs from the main game's materials, and the Hand appears above it. The remaining Hand disappears after a placement. In step 5 the text says the Hand refilled while the Hand is absent. See `baseline-tutorial-intro.png` and `baseline-banked-hand-hidden.png`.
- **Score teaching:** repeated prose and “queued” values differ from the main game's live Points × Mult treatment. The combination explanation and inventory extend below the fixed Continue region; scrolling is available and Continue remains reachable. See `baseline-combination.png`.
- **Sell teaching:** it teaches the details-panel Sell action without mentioning the game's drag-to-sell alternative.

Played all 24 guarded steps. Each intended action was reachable and accepted: initial select/place/bank, four purchases, marker attachment, line clear, Fresh Ink, Bookmark and Buff sales, End Turn, and Cash Out. Observed initial bank 65; combination 265 × 2 = 530, then Fresh Ink 265 × 4 = 1,060; sale refunds and final payout were coherent. Back to Settings returned to the same Settings surface.

Re-entered Replay tutorial and exited early. Settings returned correctly; closing it preserved all 91 projected gameplay accessibility records (81 squares, seven card identities, coins, score and Turn) exactly across the replay/exit cycle.

## Candidate recheck

Played the revised candidate's full 24-step path on the same isolated 17 Pro. All 15 counted actions completed. The Hand stayed below the board, retained six cards after placement, then visibly refilled to seven after banking. The live arithmetic showed 65 Points × 1 Mult; 265 × 2 = 530; Fresh Ink then produced 265 × 4 = 1,060. Cash Out finished with 31 practice coins. Full replay preserved all 91 projected live-game records exactly.

Actual coordinate taps set Master to 0%, 50%, and 100%, with matching rail/readout and mute copy. Music and Sound effects changed independently. Master/Music/Effects values of 100%/50%/100% survived process termination and relaunch. These checks used actual clicks, not accessibility `setValue`.

How to play, Achievements, and Privacy & support each returned to Settings correctly. Replay early exit also returned correctly; the same 91 gameplay records were unchanged after these navigation checks.

The final visual candidate removed the duplicated combination equation card, fixed faint tutorial digits, enlarged Hand cards, strengthened empty slider rails, and made the normal 17 Pro Privacy description visible. Rechecked the real final layouts:

- `final-settings-volumes.png`
- `final-tutorial-intro.png`
- `final-tutorial-hand-target.png`
- `final-tutorial-combination.png` — all six remaining cards visible above Continue.

The isolated SE (375 × 667 logical points) was backed up separately to `/tmp/NumberClub-tutorial-native-original-SE` (eight files). At normal text size, the slider labels/readouts and Close fit; the first tutorial board and outlined Hand target fit and remain clear. See `final-se-settings.png` and `final-se-tutorial-target.png`.

At accessibility-extra-large (AX3), Settings reflows labels and values above full-width rails, with Close pinned and readable. See `final-se-ax3-settings.png`. Tutorial copy grows and requires scrolling, with Exit available. Physical CUA dragging remained inconclusive; native scroll automation was inconsistent, so this review does not claim that it proved horizontal touch-pan tracking or vertical-touch cancellation. The central gesture and rendered-scroll tests provide separate coverage.

### Issue discovered during enlarged-text review

With the SE tutorial on “Start with a number,” changing text size from `large` to `accessibility-extra-large` dismissed the tutorial back to Settings. The app PID stayed 78299. This was reported immediately; the parent and layout agent identified recreation of the Settings content when its PaperSlip changed normal/AX containers.

**Fixed and independently rechecked.** Installed `/tmp/NumberClub-tutorial-settings-handoff.app` (binary SHA256 `ffedc210836fdf3a46f6cfae7d933afe4066c83b20e4199f772505647f5dd521`). In PID 81115, selected the tutorial 2 at normal text size, then changed `large → accessibility-extra-large → large`. “Give it a square,” `2 selected`, and one completed action remained intact in both directions. The subsequent intended placement worked once, producing two completed actions and +65 points. See `final-se-ax3-tutorial-preserved.png`.

## Restoration and limits

Restored both isolated simulators' original Application Support and Preferences offline, retaining their test state separately under `/tmp/NumberClub-tutorial-native-test-state-{D04,SE}`. All eight original files on each device matched their original SHA256 manifests after copying and again after reboot. The SE text size was restored and verified as `large`. No other OS settings were changed. The user's simulator and physical devices were untouched by this audit.

Native checks do not claim audible sound output, a physical VoiceOver toggle, or a successful CUA horizontal/vertical touch-drag sequence. Native coordinate taps, persistence, normal layout, destination returns, full tutorial behavior, and nested tutorial preservation across live text-size changes were verified directly. Enlarged offscreen target reachability and slider pan direction handling additionally rely on the parent's focused hosted/gesture tests.
