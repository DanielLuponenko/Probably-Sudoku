# Enlarged display layout verification

2026-09-19. This note covers the hosted responsive audit and the focused Briefing and Hand arrangement changes. Runtime memory and native Simulator evidence are recorded separately in `memory-measurements.md` and `native-review.md`.

## What changed

- The default text-size Briefing retains the existing route, board, reward slip, and side-by-side choices. Above the default size it uses a concise Chapter/current-stop heading, enlarged target and turn count, the complete reward effect, and stacked full-width choices. Text and actions are measured first; the upcoming board receives the remaining space.
- The tightest reading layout permits effect text up to 22pt and action text up to 28pt; taller layouts permit 28pt and 35pt respectively. These are explicit space constraints above the prior 12–13pt effect text and 19–22pt action text. The preview can become substantially smaller at the largest text size. It does not truncate the reward to preserve a larger preview.
- The Hand arrangement menu measures wrapped accessibility labels, removes decorative icon columns at accessibility sizes, and remains anchored to the arrangement button. Default-size labels retain their previous compact single-line presentation.
- Full-inventory replacement descriptions and named choices now scale with Dynamic Type. The existing custom article scrolls, Cancel remains pinned, and no reward/slot/skip logic changed.

## Matrix and assertions

`EnlargedDisplayTests.swift` hosts the actual Book/GameplayShell with real phone insets. The viewport equivalents are:

| Logical size | Top / bottom inset | Purpose |
| --- | --- | --- |
| 320 × 568 | 20 / 0 | Smallest zoom-equivalent stress case |
| 375 × 667 | 20 / 0 | SE-sized phone |
| 393 × 852 | 59 / 34 | Reduced modern-phone viewport |
| 402 × 874 | 62 / 34 | iPhone 17 Pro-sized phone |

Each viewport is exercised at Large, Extra Large, Extra Extra Large, Extra Extra Extra Large, and Accessibility 1–5. Five pages—Briefing, live Puzzle, Results, Shop, and Book victory—produce **180 core-page cases**. Checks include complete action text within safe bounds, no vertical page scrolling, nonoverlapping puzzle grid/Hand, full reward descriptions and Shop item names, and byte-identical game state after rendering.

Additional focused coverage includes:

- All 11 Buff rewards at maximum text size on 320- and 393-point viewports: **22 complete pre-acceptance offers**.
- Three long mandatory-boss decisions on both viewports: **6 boss Briefings**.
- Measured glyph growth for Briefing reward name, effect, and Play action, separately from fit checks.
- Named full-inventory replacement choices growing at AX5, complete-choice reachability, pinned Cancel, unchanged inventory identities and game state.
- Fresh Ink detail, long Shop offer, Redraw offer, replacement, and Settings panels on both viewports. The audit sweeps overlapping scroll offsets rather than checking only the first and last screen. A decision counts only when its complete adjacent text fits inside the article viewport; Close/Cancel must remain visible throughout.
- Anchored arrangement choices at normal and AX5 on both viewports.
- Marker inspection at all four board corners, normal and AX5, on both viewports: **16 inspected states**, with visible Dismiss, safe popup bounds, and unchanged board/Hand frames and game state.

These hosted sizes are **not proof of native Display Zoom**. The Simulator Settings surface did not expose that setting. The independent native reviewer did enable actual AX5 and Bold Text and recorded the settings and live app screenshots.

## Confirmed findings versus test-harness issues

- **Confirmed:** prior Briefing reward and action glyphs had identical heights at normal and AX5. Both the native comparison and an explicit growth test reproduced this. The new growth test passed the first focused candidate gate.
- **Confirmed:** the 320-point AX5 arrangement menu printed `Descendi…` and `Shuffle h…`. The fix retains the complete choices. A first candidate introduced an unattractive normal-size word wrap; that was caught in the hosted image and the original normal-size fitting was restored.
- **Confirmed:** a very long fixed panel heading could leave too little article height at 320 points. Root moved the accessibility heading into the scrolling article while preserving the pinned dismissal. The corrected panel sweep passed the first focused candidate gate.
- **Harness issue:** Redraw's Buy label wrapped across `BUY THIS` and `ITEM`; checking one OCR row falsely reported it missing. Exact adjacent rows are now matched as one control.
- **Harness issue:** Settings' Abandon action sits between other article sections, so checking only top and bottom could miss it. Overlapping viewport sweeps now establish reachability.
- **OCR issue:** the 320-point victory image visibly printed `Volume 8 Complete`, while full-screen OCR omitted the 8. The test retries the tightly located title crop and still requires the digit.
- **OCR issue:** the [standalone Peek image](verified-peek-ocr-zero.png) visibly prints the literal 0. Whole and cropped accurate/fast OCR, alternate candidates, language correction, and numeral vocabulary nevertheless read it as O. There is no production text or clipping defect. The test first asserts the exact current Peek catalogue definition, then permits this one complete, visually verified clause to read `scores O unless marked with Onyx`. A passing rejection test excludes altered scores, changed Clue counts, missing Onyx text, and other Buff definitions. No general digit substitution or production text change was introduced.
- **OCR issue:** [SE AX5 Skip + Buff](verified-se-ax5-skip-label.png) prints both f characters in full. Some full-page Vision passes read `Bufi`; a tight crop of the unchanged action pixels reads exact `Buff`. The matcher retries that bounded action row without spelling aliases.

## Gate status

- Baseline: `/tmp/nc-enlarged-memory-red3.log` captured the Briefing growth failure, menu ellipses, and panel-harness findings.
- First focused candidate: `/tmp/nc-enlarged-layout-green1.log` passed Briefing glyph growth, long boss rules, default route/skip layout, and the corrected panel sweep. It found the normal arrangement word wrap and the remaining Peek OCR ambiguity; both received focused follow-up changes.
- Full AppTests gate: `/tmp/nc-enlarged-memory-full-app.log` completed **751 cases with six failing methods**, all in visual tests. The 320- and 393-point core matrices, arrangement menu, Briefing growth, panel sweep, and marker edge cases passed. The 375/402 matrices stopped individual scenes on the `Buff` OCR ambiguity. The all-Buff/boss method initially stopped at a missing OCR action; it now continues after each captured case failure.
- Focused verification: `/tmp/nc-enlarged-memory-final-gate.log` passed **all 8 BriefingBoundsTests and all 10 EnlargedDisplayTests**, with zero failures in this owned scope. This rerun establishes all **180 core scenes, 22 complete Buff offers, 6 mandatory boss decisions**, the full panel sweeps, menu choices, marker edges, actual text growth, and replacement state preservation. The whole selected run completed 46 methods with two failures in separate Settings/ledger tests, subsequently resolved in the follow-ups below. The earlier 751-case and 46-method runs remain recorded with their original failures.
- Final focused artifacts were exported successfully to `/tmp/nc-enlarged-final-gate-attachments/manifest.json`. The screenshots preserve each rendered scene and intermediate panel scroll offset.
- Follow-up `/tmp/nc-enlarged-memory-last-recheck.log` passed all seven Settings methods, including the corrected enlarged Abandon decision. Independent review of its 240-point AX5 screenshot confirms the complete consequence, whole-word Abandon, and readable Keep Playing fit without overlap or clipping.
- Final ledger follow-up `/tmp/nc-enlarged-memory-ledger-final.log` passed its full composition/growth test in 20.577 seconds. The test fixture had omitted the placement operations that the actual gameplay score panel already includes; it now mirrors the real UI composition. No production ledger repair or OCR substitution was needed.
- The central audit reports **756 distinct app test methods with a latest passing result** across the full run and focused reruns, with no unresolved failing method. This is accumulated verification, not a claim of one clean 756-method execution. The Briefing/arrangement/replacement production files and both owned suites stayed unchanged after their passing run.

Native candidate screenshots include [17 Pro AX5 + Bold Briefing](candidate1-17pro-ax5-bold-briefing.png), [SE AX5 Briefing](candidate1-se-ax5-briefing.png), [SE AX5 arrangement](candidate1-se-ax5-arrange.png), and [SE AX5 replacement at the article bottom](candidate3-se-ax5-replacement-bottom.png). The native reviewer confirmed the full Peek effect and both decisions on both phones, all three arrangement choices and an actual Descending selection, and replacement cancellation and acceptance with inventory identities preserved. Independent inspection of the replacement screenshot confirms the complete enlarged Fresh Ink choice/effect and pinned Cancel are readable, with no overlap or bottom clipping.
