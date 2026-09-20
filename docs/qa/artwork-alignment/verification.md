# Bookmark and Buff artwork alignment

Verified 20 September 2026.

The inventory was positioning its artwork four points below the card center.
The original glyph crop also retained paper/notch edges and dark card backing,
while clipping parts of some symbols. Inventory artwork now isolates the
supplied symbol, preserves Bookmark color accents, and centers the visible
pixels within a transparent square. Full Shop tile illustrations are unchanged.

## Verification

- Debug simulator build passed.
- 35 targeted tests passed, zero failures: ItemArtworkAlignmentTests,
  ExpandedCataloguePresentationTests, InventoryDragTests,
  ShopOfferCardRenderingTests, BuffSlipPresentationTests and
  ScoringSourceHighlightTests.
- All 50 Bookmarks and 40 Buffs checked for transparent surroundings, visible
  artwork bounds and centering. Real inventory cards checked at 40, 44 and
  52 point widths.
- Production Puzzle and Shop views rendered at 375 × 667 and 402 × 874.
  Rendering preserved the encoded game state.
- Independent visual review confirmed orientation, retained color/details,
  no clipped strokes, no nested card backgrounds, and centered inventory art.

Screenshots in this folder come from the tested SwiftUI views. Earlier boss
animation recordings predate this artwork correction.

The test result bundle is `/tmp/NumberClub-artwork-alignment-20260920.xcresult`.
Simulator installation and save preservation are recorded in `installation.json`.
