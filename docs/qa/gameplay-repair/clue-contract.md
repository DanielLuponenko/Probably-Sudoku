# Clue interaction contract

Clues from Book rules, Puzzle Corner and historical saves remain puzzle resource charges. Their compact lightbulb/count control sits beside Help and Settings. They never occupy a third Buff slot. The bottom action row contains Toss and End Turn only.

A stored charge follows `resource → hand card → revealed square → player placement`. Activating the resource clears any previous hand selection. Entering targeting does not change the saved game. Choosing a valid card spends one charge and records one legal destination; the held card remains unchanged until the player places it. The hand instruction and the board's lightbulb/outline identify the destination. Selecting that number again restores its paid hint without another charge.

An inventory Peek follows `Peek → Choose number → hand card → revealed square → player placement`. The custom Buff panel describes that handoff. Closing the panel transfers input to targeting, with the selected Peek UUID retained in its original inventory slot. A valid card choice consumes that exact Peek, grants/spends its clue and records the destination in one copied Game assigned once. If that number already has an eligible paid destination, the Peek stays held. Duplicate Buff and card copies keep separate identities.

Cancel, an unrelated overlay, dragging, backgrounding or leaving gameplay clears pending targeting without spending the charge or Peek. Pending targeting is deliberately transient: saving/resuming before a reveal retains the original inventory/charges; saving/resuming after a reveal retains the consumed copy and revealed destination together. A stale Peek UUID cannot consume a replacement item. A blocked card or missing destination leaves targeting armed for another choice and retains all resources. Paywall blocks all new Clues; Buffborger blocks activating/consuming Peek while independently earned Clue charges retain their established behavior.

Clue placement retains its intentional scoring rule: zero placement Points unless Onyx restores the placement score. Engine scoring owns that result.

The visible Pool badge is removed. Toss, Redraw and wrong-placement returns fade toward an invisible one-point anchor at the hand's trailing edge, without adding a label, revealing counts or reserving new space.

## Evidence status

Focused app regressions passed, including `HandCluePresentationTests`. The [actual Flow/Clue playtest](flow-clue-playtest.md) records the real Peek panel → fresh hand selection → revealed destination → explicit placement flow, duplicate hand cards, cancellation, Puzzle Corner charges, Paywall/Fine Print restrictions and paid-hint save/resume. The [final independent review](final-independent-review.md) additionally passed process restart while Peek was armed with byte-identical saved state, and a barred duplicate-card attempt followed by a legal duplicate reveal. The [verification report](verification.md) tracks the final integrated gate.

The old bottom button and immediate use of a previously selected card were confirmed inconsistencies. Source inspection alone did not prove a panel-dismissal failure; the successful integrated handoff above was verified through actual player controls.
