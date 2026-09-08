# Shared paper UI

Use the existing cream stock, charcoal print and the current Book's accent.
Information must fit its content; it should not become a second full Book.

## Three related surfaces

- **Printed label:** `paperSurface(kind: .label)`. Short rules and item details.
  A small illustration, printed title and one concise explanation. No separate
  numeric badge repeating the explanation. Book selection uses its existing
  stationary sign for benefits, not a second label below the cover.
- **Paper slip:** `PaperSlip`. Buffs, Marker placement, item inspection,
  confirmations and Settings. Shared heading, rule, spacing, paper edge and
  shallow shadow. Short content fits; long content scrolls with the close
  action outside the scrolling content.
- **Book page:** existing `BookView` and gameplay/results pages. Retain their
  larger hierarchy, using the same print, stock and action colors.

## Content and actions

- Use `PrintedItemIllustration` for small detail illustrations. Its declared
  size includes the paper padding; do not add a second oversized decorative card.
- `PaperButton` supplies consistent press feedback and a minimum 52pt height.
  It grows for larger text rather than clipping its label.
- Book accent = primary action. Charcoal = content. Red = warning or destructive
  replacement, not generic emphasis. Handwriting is for jokes, not instructions.
- Unfinished-Book decisions state the saved progress, offer a primary Continue,
  explicitly explain replacement, and expose one dismissal control. Avoid
  nested option cards and redundant Cancel/Close/Keep actions.
- Mandatory Marker placement has no escape action that can discard the purchase.
- Native sheets use `dimsBackground: false`; do not double-dim the underlying
  Book or replace the native purchase/dismissal handoff.

## Layout and motion

- Typography uses Dynamic Type metrics; essential text can wrap. Complete
  Book benefits remain available to accessibility; obstacle details use a slip.
- During selection the existing sign replaces identity with the Book's benefit.
  Selected Books show only a centered benefit title, without an explanatory
  subtitle. Full rules remain available to accessibility.
  Its shallower frame fits between the Dynamic Island and the top Book, with
  at most two cached print textures. There is no lower benefit banner or
  selection dimming. A finite erase/write mask reveals the lettering across
  the existing face; the frame does not fade or move. Reduce Motion settles
  immediately, including when enabled during a write.
- Center the complete cover-and-bookmark silhouette. Open follows below it as
  a compact 52pt-high cloth-faced button, capped at 280pt wide. Its raised edge
  compresses only on a press; it does not bob continuously.
- Keep the sign and Open action separate from the extraction/return transform.
- Brief event-driven settling/writing and shared press feedback only. No continuously
  animated informational panel, new texture allocation per frame or decorative
  particle layer.
- Do not shrink the puzzle board to accommodate a detail panel.

## Regression coverage

`PaperDesignSystemTests`, `BookBenefitPlaqueRenderingTests`,
`BookstoreSelectionTests`, `BuffSlipPresentationTests`,
`ShopBookmarkPresentationTests`, `ShopMarkerHandoffTests`,
`ShopOfferCardRenderingTests`, `SettingsPresentationTests` and
`PuzzlePageLayoutTests` cover representative sizing, copy, handoffs and geometry.
Rendered/hosted tests do not certify physical VoiceOver, speaker or haptic feel.
