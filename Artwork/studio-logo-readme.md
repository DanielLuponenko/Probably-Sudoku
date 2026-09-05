# DLA Game Studio logo

The active studio intro is the native vector artwork in
`App/Views/StudioSplashView.swift` (`DLALogo`). It uses capital D and A, a straight
red lowercase l, and the inscription **This is not an i**. A continuous rotation
and zoom enters the final i's dot. As soon as the dot covers the viewport, a
0.12-second dissolve reveals the book menu, already prepared beneath the logo.
There is no extra white hold, fight animation, or demo board.

Glyph outlines and the dot target come from the same cached Core Text paths,
so the closing zoom remains sharp and centered. Reduce Motion shows a static
logo followed by a short cream dissolve. `StudioIntroView` uses the same intro.

`dla-intro-approved.html` preserves the approved interactive design reference.
For simulator QA, `-holdStudioSplash` holds the opening logo and
`-studioSplashTime <seconds>` holds a particular animation frame (Debug only).
`AppTests/StudioLogoTests.swift` covers alignment, continuous magnification,
the dot filling phone/tablet viewports, and the Reduce Motion camera.

## Archived DannyLovesAnna artwork

The previous files below are retained as rollback evidence. The app's studio
views no longer display these images.

## Deliverables

- `studio-logo-full.svg` / `.png` — detailed badge and wordmark.
- `studio-logo-horizontal.svg` / `.png` — credits and wide placements.
- `studio-mark.svg` / `.png` — standalone square mark, exported at 32, 64, 128, 512 and 1024 pixels.
- `studio-logo-mono-light.svg` / `.png` — one-colour black on cream.
- `studio-logo-mono-dark.svg` / `.png` — one-colour cream on black.
- `studio-mark-mono.svg` / `.png` — one-colour standalone mark, also exported at 32, 64, 128, 512 and 1024 pixels.
- `studio-mark-mono-on-light.svg` and `studio-mark-mono-on-dark.svg` — explicit light/dark field proofs, also exported at the same sizes.

The wordmark is set by hand in the SVG sources; no generated lettering is used. The compact mark is a separate, fully-vector source so it remains recognisable at 32 pixels. `studio-couple-illustration.png` is retained as the no-lettering design exploration that informed the simplified, shipped vector mark.

## Palette

| Role | Colour |
| --- | --- |
| Ink | `#11100F` |
| Paper | `#FFF4D7` |
| Heart red | `#EE2632` |

The controller from the reference is intentionally removed. The mark keeps the couple and heart but has no generic game clip art, and remains distinct from the Probably Sudoku app icon.
