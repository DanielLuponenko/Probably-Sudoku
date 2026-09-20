# Independent native marker inspection review

2026-09-19. Tested the real app using the native Simulator accessibility actions and coordinate input. QA fixtures were used to arrange marked positions, not as substitutes for the interaction under test. No production source was changed during this review.

## Builds and devices

- Build 4: `/tmp/NumberClub-marker-inspection-build4.app`, debug dylib SHA-256 `32e7b4089650ffa1573dfbb34b322a884b213e0febd0bdc42020655de1b5ed65`.
- Final recheck, build 6: `/tmp/NumberClub-marker-inspection-build6.app`, debug dylib SHA-256 `ca2677cbbc453818ef2288681314dce3fb7d551810c9ba3404963f617e9db65a`.
- iPhone 17 Pro: reviewer device `D04D3836-357E-4E92-811D-6D14E3BA1E01`, normal text.
- iPhone SE: reviewer device `60D48736-12BA-4D48-ADCB-DC2DBB834730`, normal text and largest accessibility text (`accessibility-extra-extra-extra-large`). Text size restored to `large` afterward.
- User device `223A4227-A28E-4939-BB5E-3AAB820EB635` was not touched.
- Launch fixture: `-skipStartScreen -seed marker-hold -gameplayFixture markers`; Accountant and Fog used the actual `-qaBoss accountant` and `-qaBoss fog` raw IDs.

## Verified

- Accountant board no longer has the receipt lines or decorative board marks shown in the complaint. Real wells, grid, numbers and owned marker symbols remain. Final image: [resting board](native/17pro-rest-accountant-build6.png).
- iPhone 17 Pro: selected Number 2 before inspection. Jade at the bottom edge opened above its square, with the complete explanation including the explicit wrong-placement penalty caveat. Same hand-card UUID remained selected after dismissal, with 5 coins, queued base 0, seven cards and Turn 1 unchanged. Final image: [Jade with selected card](native/17pro-jade-selected-build6.png).
- Ivory under a given at the top-left repositioned below the square. Full availability explanation says the printed number prevents this marker triggering here and ownership remains for later puzzles. [Image](native/17pro-ivory-given-top-left-build4.png).
- Azure at the right edge remained inside the screen. [Image](native/17pro-azure-right-edge-build4.png).
- A real coordinate short tap at row 1, column 5 after those inspections placed the selected 2 exactly once: seven hand cards became six, queued base became 20, Accountant charged one coin (5 to 4), and the turn remained 1. This was a normal touch click, not a QA placement action.
- iPhone SE normal text: Rose's full ongoing multiplier explanation and dismissal were readable and remained within the screen. [Image](native/se-rose-normal-build4.png).
- Fog: actual marked fixture board exposed neither marker symbols nor marker names, explanations or Inspect marker accessibility actions. The existing question-mark map remained available and showed the concealment notice without exposing marker buttons. [Board image](native/se-fog-hidden-AX5-build4.png).
- At largest accessibility text on SE, build 6 shows a fixed Dismiss footer while the long explanation occupies its own scroll region. Accessibility exposes Jade heading, the complete explanation, and Dismiss; underlying board elements are excluded while the accessible popup is open. Dismiss worked and returned to the unchanged puzzle. [Fixed image](native/se-jade-AX5-dismiss-fixed-build6.png).

## Issue found and fixed

Build 4 put Dismiss after the long text inside the scroll region. At SE AX5, it was below the visible fold and the native accessibility snapshot failed to expose the popup's children, leaving board controls exposed. [Preserved failure](native/se-jade-AX5-clipped-build4.png).

The root implementation moved Dismiss to a fixed footer and made accessible inspection modal for accessibility. Both corrections were verified in the actual build 6 app on SE AX5 and iPhone 17 Pro. The screen stays visually undimmed and the board and HUD remain stationary.

## Verification limits

- The supported CUA API has no duration-controlled press-and-hold. One same-point drag on the top-left given behaved as an ordinary short tap, selecting its visible digit rather than holding. Therefore this review does not claim physical 400 ms recognition, release/cancellation or haptic sensation was manually verified. Those need the focused recognizer/state tests and eventual physical-device input verification.
- CUA's native scrolling/dragging on the SE window returned `windowNotFoundAtPosition`, including after raising/centering the window and targeting the text accessibility element. Thus manual scrolling through the AX5 text was not verified here; root separately ran the hosted before/after-scroll layout test. Full content is present in the native accessibility explanation.
- A native iOS Reduce Motion setting was not changed; the app's settings correctly state that it follows iOS Reduce Motion. No native Reduce Motion pass is claimed.

Simulator/CUA ownership was released to root after final captures and dismissal. No additional code issues remain from this bounded native review.
