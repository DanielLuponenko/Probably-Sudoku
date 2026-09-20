# Independent native interaction review

20 September 2026. A separate reviewer operated the final build on the isolated SE-test simulator, using the non-saving marker fixture. No production save, app lifecycle, system setting, or build was changed during this pass.

| Interaction | Observed result |
|---|---|
| Arrange → Descending | Small anchored menu; hand became 9, 9, 8, 7, 3, 2, 1. The exact selected 1 and both distinct 9 identities were preserved. |
| Inspect Jade; dismiss | Full current definition readable, explicit dismissal available. Selection, empty cells, score, coins, Toss allowance and turn unchanged. |
| Inspect given-covered Ivory; dismiss | Availability reflected the covered square; inspection did not mutate gameplay. |
| Settings accessibility | Navigation entries expose button roles; volume controls expose slider roles. |
| Settings → Help → Topics → Markers → Close | Current marker artwork and definitions displayed. Returning through Settings preserved the selected number. |
| Place selected 1 at row 1, column 6 | Consumed one hand card and displayed live +10 from 10 × 1. |
| End Turn | Banked 10 once, refilled one card, advanced to Turn 2/10; coins remained 5. |

No app defect was identified in these interactions. The simulator was left on Turn 2.

## Screenshots

- [Selection before interaction](after/independent-selection-before.png)
- [Arrange menu](after/independent-arrange-menu.png)
- [Marker inspection](after/independent-marker-inspection.png)
- [Marker Help](after/independent-guide-marker.png)
- [Live placement score](after/independent-live-score.png)
- [After banking](after/independent-bank-after.png)

## Limits

Inspection used the accessibility action, not a physical press-and-hold; haptics were not assessed. Synthetic guide scrolling moved once and then stalled, so this pass does not establish native bottom-of-article reachability. Hosted scrolling and fixed-Close checks passed separately. This review is evidence for the listed interactions, not a full-device accessibility or performance certification.
