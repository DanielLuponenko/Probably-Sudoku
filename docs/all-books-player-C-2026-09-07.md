# Player C — Volumes 9–12 (2026-09-07)

## Volume 9 — Small Victories, Big Ego

- Native UI evidence: title menu snapshot `/tmp/numberclub-ui-C/results/1788732326989-2d7512d0-e3e9-4b31-a2e6-02b7f3e85ef0.png`; rack snapshot `/tmp/numberclub-ui-C/results/1788731243478-77dcb31c-c4ed-4177-8dd6-ed363709940f.png` visibly showed the Volume 9 cover.
- Selected cover using observed normalized point `(0.5, 0.78)`; completion `/tmp/numberclub-ui-C/results/1788732343112-1ebb0fc4-f408-44bf-ac06-92c9f56426ec.png` exposed “Return book to shelf” and Volume 9 UI.
- Opened using observed bottom action point `(0.5, 0.965)`; completion `/tmp/numberclub-ui-C/results/1788732370182-235becd8-4e60-4166-aae1-4ef0d49280e7.png` showed “Opening the book”.
- Puzzle setup snapshot `/tmp/numberclub-ui-C/results/1788732378524-d3f329dc-e890-495b-b204-2d7a2c3e801b.png`: “NEXT PUZZLE”, “ROUND 1 OF 3”, “LEVEL 1 · RUN PLAN”, current stop “Easy”, and “Play Puzzle →”.
- Issue: semantic `tap-label` for visible PLAY and OPEN THE BOOK returned `notHittable`; image-grounded coordinate taps worked. Recorded as an interaction/accessibility issue, not yet triaged.

### Volume 9 Level 1 — Channel C native run (Puzzles 1–3)

- Puzzle 1 passed normally: five helper-verified visible singles in Turn 2, then later visible singles; completion screen screenshot `/tmp/numberclub-ui-C/results/1788733219100-1429b619-bed4-48e6-b27c-9af5da261aec.png` showed `Puzzle Complete`, `1,380 / 1,000`, and 5 unused turns. Cashed out.
- Shop choice after Puzzle 1: bought visible `Puzzle Corner` (+1 Clue every Puzzle) for 6 coins; purchase confirmation/sold state `/tmp/numberclub-ui-C/results/1788733266652-94d635b4-d72c-44f4-9176-713b1a79d271.png`.
- Puzzle 2 passed normally: completion screenshot `/tmp/numberclub-ui-C/results/1788733659755-1560de79-17b6-4a22-8058-d2d298601da0.png` showed `Puzzle Complete`, `1,670 / 1,500`, and 5 unused turns. Cashed out.
- Boss shop choice: bought visible `Overtime` (+2 Turns this Puzzle) for 4 coins; equipped state `/tmp/numberclub-ui-C/results/1788733705575-ec1f903e-86df-4d63-9254-4bcdc82fae7d.png`.
- Puzzle 3 boss `Gray the Garry` failed through normal play: visible row-lock rule did not block verified placements, but Toss reached `0 left this puzzle` and became disabled; after Turn 10/10, settled failure screenshot `/tmp/numberclub-ui-C/results/1788734082455-6afef11a-009a-42f7-bebc-4fbf04c4590f.png` visibly showed `Out of turns`, score `490`, target `2,000`, optional `Watch ad · +3 turns`, and `End book`.
- No product/source edits made. Several long helper calls hit the shell’s 30s output window while native UI continued settling; fresh snapshots confirmed subsequent placements and both puzzle-complete states.

### Volume 9 retry — second native run (Level 1 complete; paused at Shop)

- Restarted from the normal menu and replayed Puzzle 1 and Puzzle 2. Puzzle 1 completed at `1,280 / 1,000` (12 total turns visible); Puzzle 2 completed at `1,690 / 1,500`.
- Purchased and equipped `Morning Edition` (+100 points at end of each Turn), then purchased and equipped `Op-Ed Column` (+1 mult) for the boss. Tapping each visible buff opened passive details with no separate `Use` control; effects were shown in the HUD (boss queued `+200 × 2`).
- Boss Puzzle 3 (`The Censor`, one random number scores no points) started normally. The helper’s first pending command later resolved without a placement, leaving Number 9 selected with an advanced visible deduction at row 7/column 3 (proof trace `/tmp/numberclub-ui-C/deductions/1788735288375-1c491c58-2706-4f98-99ce-88a760fb8b21.json`). A subsequent direct placement command `1788735904131-697db3de-4beb-45ad-a757-2e96c157690f` remained pending with no result file; no command was resent.
- Root restarted the native runner (Release pid 262) and quarantined two old unstarted command IDs. Re-entered Volume 9 normally from fresh title-menu evidence `1788751632141-8c5e5cf0-b456-4c8a-97a1-a9c250fe115a`, selecting the observed cover and `OPEN THE BOOK` by screenshot-grounded points.
- Resumed saved Level 1 Puzzle 3 with passive `Morning Edition` (+100 points/end Turn) and `Op-Ed Column` (+1 mult). No `Use` control appeared because both are passive Bookmarks. Public AX showed Puzzle 3/3, Level 1, with no unrelated Boss/Deadline.
- Normal visible-single play completed Censor at `2,140 / 2,000` on Turn 6, with `5` unused turns and `12` total payout. Completion snapshot `1788751912153-48aef52a-17b0-494c-a35c-ec4c9134bc3b`; cash-out result `1788751932202-48262634-5c58-4746-b15b-bb5733bb5938`.
- Current next-puzzle Shop snapshot `1788751932202-48262634-5c58-4746-b15b-bb5733bb5938` shows `32 coins`, affordable Evening Edition (5), Society Pages (7), Jade Marker (6), Azure Marker (6), and Redraw (3). Paused here for Release duplicate-offer-control retest per root; no purchase made yet.
- During this retry, passive Bookmark effects were visibly reflected: `+200 × 2 queued` at Censor start and per-turn score breakdowns showed multiplier `×2`; no consumable Buff was available or activated.

### Volume 9 retry — Level 2 native continuation (Round 2)

- Cashed out Level 2 Puzzle 1 at `2,660 / 2,000`, with 7 unused turns and total payout 14; settled evidence `/tmp/numberclub-ui-C/results/1788752846501-acc31829-c831-46a4-876e-a01db28ff157.png`. Cash-out increased the visible balance from 29 to 43 coins.
- Shop evidence after that cash-out (`1788752846501…`) showed fresh offers Paper Route (5, +2 coins per Puzzle win), Evening Edition (4, +300 at Turn 10), Sapphire Marker (6, draw 1), Golden Marker (6, +100), and Paper Crane (3, +50 flat for a chosen number for the Puzzle). Purchased Paper Crane normally via details and `Buy this item`; exact purchase/sold and HUD evidence `/tmp/numberclub-ui-C/results/1788752870710-3ac8faa2-cb80-4c59-8014-13c406623ea1.png`; balance became 40. No duplicate offer controls were present.
- Continued normally to Round 2/3, Level 2 “Easy but hard”; briefing `/tmp/numberclub-ui-C/results/1788752881637-a7359aa5-b491-4ff2-b96e-d2be7092c529.png` showed the authored full-width Book scene and The Fog boss preview (`Markers hidden`). Optional Coupon clipping was visible as `+8 coins now`, with `2 LEFT`; deliberately left it unused to complete all puzzles normally.
- Level 2 Puzzle 2 started with passive Morning Edition and Op-Ed Column plus Paper Crane in a HUD Buff slot. Opened Paper Crane, selected Number 3, then used it; modal selection evidence `/tmp/numberclub-ui-C/results/1788752928061-65626ec2-eb21-41c0-aba2-f4d4e4273d39.png`, post-use evidence `/tmp/numberclub-ui-C/results/1788752935897-3915bb0a-e739-43c3-8d2f-e998e5fd64a5.png` showed the Buff slot cleared. This is a verified normal consumable Use flow.
- Visible-turn helper placements were all confirmed. At Turn 4 score reached `2,680 / 3,000`; evidence `/tmp/numberclub-ui-C/results/1788753114669-80c52fe8-16df-4aef-a621-fa9fe2916d8d.png` visibly showed Op-Ed Column feedback (`+1 mult`) and full-width Book coloring, with no color/underprint issue observed. Puzzle then auto-completed after the next confirmed placement; helper correctly reported no active puzzle rather than resending.
 - Level 2 Puzzle 2 completion settled at `3,960 / 3,000`, 6 unused turns, interest 4, total payout 15; snapshot `/tmp/numberclub-ui-C/results/1788753156083-99c5ad20-2ba9-43d6-9ca7-d2c6240233f0.png`. Current balance remains 40 before cash-out. No unrelated Deadline/Boss appeared in normal puzzle AX. No product/shared helper changes made.

### Volume 9 retry — Level 2 Boss continuation (bounded C batch, 2026-09-07)

- Verified live readiness `ready` at `1788761898.225656`; title PLAY `1788761923637-e20918ec-86a5-46fb-b871-5166747a0885`, Volume 9 selection `1788761939816-b1bf4b39-51e6-433d-b558-412944d57be4`, book opening `1788761949848-807ed8a4-93d1-4555-980d-bd64871506a5`, settled Shop `1788761955690-f0ac780d-2a32-490a-8ec4-20cbb9e8758b`.
- Exact Shop screenshot showed 55 coins and affordable Market Wrap 6, Auction Notices 6, Golden Marker 5, Silver Marker 7, Peek 3. Laurel/marginalia stayed inside page margins without overlapping offer text/icons (UI-14 evidence). Identifier tap returned XCTest `notHittable`; coordinate tap opened details. Purchased Peek normally for 3 coins; sold-state receipt `1788762002550-6528db80-d8c7-4287-98af-297f08ee023c`, balance 52.
- Level 2 Puzzle 3/3 Boss The Fog briefing `1788762015672-8de2d874-1050-4122-8751-3f5a9a063252`; puzzle start `1788762022369-ecd9f6a8-8cbc-4ff8-bb38-ae0d91017a65` showed Turn 1/10, target 4,000, and margin note “Please keep the victory lap inside the margins.”
- Public-only play placed 5 at r1c1 (`1788762054782-c5a427da-bbc8-46ae-8b21-c11aa257dfb0`), then helper-confirmed 6 r4c2, 7 r3c2, 4 r3c1, 6 r8c1, 7 r9c1; final `1788762077297-314934c8-cf84-4de7-aaf8-22cb3d4b3a8e` showed Turn 2/10 and score 0 during immediate post-placement capture; settled/resumed score pending verification. Stopped at 25-command player cap; no Book completion claimed.
- C-05 resume verified the six placed cells and settled score `800` at Turn 2/10 (`1788762445389-349bf63f-6220-4748-85f2-5345d6fc29b7`), confirming the prior score 0 was transient. Normal continuation used Peek: alert `1788762471601-06e80685-affb-4b41-8fa4-b5592c76c0d3`, Use failed via label (`notHittable`) then coordinate Use `1788762484575-4d7deb38-36d7-4f66-81a4-31dd9a30e114`; chose 4 and placed the clue at r1c9 (`1788762497584-d83ad3cf-2e87-4cd1-94ce-70bb06a045f1`), advancing to Turn 3 and score 1,320 after settlement. End Turn receipt `1788762543353-78e2579c-12ed-4428-83c7-0684a8744011` showed score 1,320.
- Additional public play placed 2 at r2c6 (`1788762581675-13aecaaf-1c32-4408-84a7-36723a07158c`) and selected 9 at final checkpoint; final receipt `1788762597960-d346ba5e-a39d-40de-9c97-547e9d11826e` remained Turn 4/10, score 1,420 with 40 points queued. C-05 stopped at the 32-command cap; no Book completion claimed.
- After the cap extension, selected 9 and placed it at r2c9; End Turn receipt `1788762625075-8727afae-e8a4-4596-9a99-175caa01e46b` advanced to Turn 5/10 with score 1,420 and the settled prior hand state preserved. No Book completion claimed.

### Volume 9 retry — Level 2 Boss continuation (C-06 bounded batch)

- Fresh readiness receipt was `1788763008.8585691`, newer than the C-06 resource start. Normal resume receipts: PLAY `1788763025680-baae9efc-3ce3-4a9d-9dc3-944beedabcc5`, Volume 9 selection `1788763039419-e61f18f7-25db-4f3b-8d21-e3833e4bf302`, opening `1788763114237-99e944d2-d752-4de7-a914-05a6eb41ec4d`.
- Settled/resumed Fog screenshot `1788763118250-764eb318-a271-4514-b5ab-92ba6822d3ff` showed score `1,860 / 4,000`, Turn 5/10, and all prior visible placements preserved (including the six original cells); current hand was 4, 5, 8, 8, 4, 7. The public helper was attempted but refused the visible clue suffix (`Unknown/masked board cell ... number 4, clue`); no hidden state was used.
- Normal visible play placed 8 at r8c2 (`1788763143770-9ce41d0a-3b61-4f5e-b786-3074627bb9dc` then `1788763148558-c29f1777-dd47-4ce2-9462-b39c538846e2`). Semantic End Turn returned XCTest `notHittable` (`1788763158727-c8a99851-4603-4f6d-9995-a53b6750188f`); observed coordinate End Turn worked (`1788763163847-888cf76a-1e85-4588-a730-e567eaa0b500`), advancing to Turn 6 with 400 queued and score 1,860.
- Used normal Toss on unhelpful visible cards: Toss prompt `1788763179953-b9c16c9d-c3d0-48de-a535-73d151fc5537`, selected/tossed 4 `1788763185513-cf5fae03-dbb0-4ebf-9800-596ca934aa44` → `1788763189688-eecad017-f051-4332-acb4-c629acdd2072`; End Turn advanced to Turn 7 (`1788763203153-9fad2047-af49-4773-a1fd-2bfb9a8da82c`) at score 2,360.
- Selected visible deduction 2 at r3c3 (`1788763208913-6b6e2fcc-edf6-4159-8f60-0c8df186502a`), but the following receipt still showed the cell empty; placement was not confirmed. End Turn `1788763216516-6930ceb0-5376-4d1e-a486-2f7f26a5a045` advanced to Turn 8 with score 2,460. Tossed another unhelpful 5 (`1788763222743-97f50ed0-40aa-4866-bfb9-0d731adb4cf4` → `1788763229185-60c39df1-fa6c-4bd2-a0fd-53df7659bef5`); End Turn `1788763242554-adb32cbd-2253-4db1-8c7e-7846ef62bdfe` reached Turn 9 at score 2,560.
- Final attempted card-selection command did not produce a receipt before the supervisor’s normal C-06 exit (`exitCode 0` at resource timestamp 1788763250356); it was not resent. Current safe checkpoint is the saved Fog boss at Turn 9/10, score 2,560/4,000, no Book completion claimed.

### Volume 9 retry — Level 2 Boss continuation (C-07 bounded batch)

- Fresh ready receipt `1788763593.194663`; normal resume path used PLAY `1788763612011-57c28344-7c4f-457d-a4a1-d8fad4528777`, Volume 9 selection `1788763632184-94309d5b-bd8e-48c2-ac8c-379f219c7964`, and opening `1788763643194-3827b0f4-ab05-4f69-9700-8e7cc14bf144`.
- Settled/resumed Fog screenshot `1788763648464-b9244879-6d72-4a92-8ac2-5751a02178d8` showed score `2,660 / 4,000`, Turn 9/10, and the preserved prior placements. Repaired public helper successfully placed visible deductions 2 at r3c3, 6 at r3c9, and 8 at r7c7; final helper receipt `1788763662318-bc8619c0-47ab-4db3-8f69-0b3957c4d933` was Turn 9/10.
- Settled helper snapshot `1788763669401-77f928c8-74c5-4cba-99eb-27cbe9c3d5db` showed score `2,660` and only 7 remaining. Coordinate End Turn `1788763680638-572157e8-834e-403b-88d1-b325ae61b613` advanced to Turn 10/10 with hand 7,5,3,8,3,3. Helper then placed 5 at r9c9 and 8 at r9c6, ending at score `3,300`; no further public deductions remained.
- Final coordinate End Turn `1788763697994-34b3bff5-55b9-426d-97b0-e2a5f1cb1d5e` was an immediate gameplay/score-animation capture showing 3,300. The settled failure receipt `1788763703755-372a73b6-614c-4889-9bef-e3e46cb99519` shows 3,660 against target 4,000 and Watch ad +3 turns. Used the optional visible test ad once: receipt `1788763718409-5553c31f-64cc-4b61-a6ba-48a3235daac2`; follow-up snapshot `1788763724853-c30b7824-6350-4ccd-9add-6fed889cf800` showed the native test advertisement with Congratulations and Close Advertisement still disabled. No restart or additional action was attempted. Book completion not claimed.
- Additional post-ad snapshots `1788763781329-adebf906-8751-4a07-b9c7-74d2a2b2e197` and `1788763793225-09d344d5-9e3f-41a3-ba94-c22eed4d77f6` showed Reward granted inside the test advertisement. The separate enabled native inner `Close` button at the top-right was visible; no Get/install action was taken. Resource sampling remained live at timestamp 1788763795666.

### C-08 bounded continuation

- Fresh ready receipt `1788763920.6939778`; normal resume used PLAY `1788763939685-df396c51-e365-4728-a3a5-26c798710862`, Volume 9 selection `1788763951696-ede5c529-7cd6-4cd0-b1fb-b5eec16dbaeb`, and opening `1788763962713-40b54d75-d34c-45f4-a10a-62cd088b01d5`.
- Reward persistence verified: settled Fog state `1788763968638-be4a5886-0f1e-4a1e-9512-56809ce73dd7` resumed at Turn 11/13 and score 3,660. Root compared all 81 public board labels and the six hand cards (7, 3, 3, 3, 9, 1) with the last pre-ad board receipt; both matched exactly. Public helper then placed 9 at r5c1 and 1 at r9c4 (`1788763976603-dc5b8a49-ee08-484a-b21c-f0e9cad6f367`, `1788763979378-780f09b6-8092-4a14-88b3-c0e78b2db54b`); their points were banked on the subsequent End Turn.
- End Turn `1788763984343-09679fef-2432-4611-bbe7-c2ba8ce84322` advanced to Turn 12/13. A settled snapshot `1788764007508-314b449c-b529-4365-ba7e-1f712f7bb0d2` showed `Puzzle Complete`, score `4,080/4,000`, 2 unused turns, and total payout 12. Cashed out normally `1788764035433-b5d1a982-0d60-4c35-a82b-44ab3b544e12`, balance 64.
- Shop visibly offered Paper Route (+2 coins per Puzzle win), Weather Forecast (+2 Toss allowance), Golden Marker (+100 points), Jade Marker (wrong placement returns to Hand), and Peek. Purchased Golden Marker for 6; sold-state purchase receipt `1788764063435-5048f4c3-022c-4949-8d33-dd8779a78c31`, balance 58. The subsequent marker-placement interaction succeeded and returned to Shop at `1788764152415-8f7c4323-4bb2-41df-a5e6-dcdbb1e4db61`; position was not separately claimed from the Shop screenshot. Unstarted Continue `1788764167300` was quarantined by root. Book completion/unlock proof remains unclaimed.

### C-09 bounded continuation

- Fresh ready receipt `1788765085.7211552`; normal resume used PLAY `1788765115041-9dc00b70-f969-455b-bb03-0e4796057701`, Volume 9 selection `1788765127863-2d7320bb-d02b-4e9a-a5df-fa435b4c450e`, opening `1788765138615-5f494e13-000a-42a8-9039-70508a40b055`, and settled book view `1788765144476-7f328c1e-1321-4776-9519-328fbf59e1dc`.
- Shop confirmed 58 coins with Morning Edition, Op-Ed Column, and Golden Marker retained. One visible reroll (`1788765159089-f22de139-4a85-4865-852b-74658c08b289`) cost 2 and offered Sports Section (Line Clears +25), Help Wanted (+1 hand size), Sapphire Marker, Emerald Marker (Line Clear x2), and Overtime (+2 Turns). Purchased Sports Section for 5 (`1788765182179-ae98fbc8-e5b6-4145-9aaf-59638cdf8681`) and Emerald Marker for 7 (`1788765196562-731cd811-3198-432c-bfca-62987c866d66`), leaving 44 coins. Marker picker was shown with all rows visible; coordinate selection receipt `1788765225079-6015b6b6-f1d3-4999-aba5-55ae032576dc` returned to Shop, but no separate position claim is made from the arrival-fade screenshot.
- Continued normally to Level 3 Puzzle 1. Helper confirmed public placements 3@r1c3, 5@r1c5, 2@r2c7, then 5@r2c9, 7@r3c7, 8@r3c5 across receipts through `1788765295274-f808c4df-0196-4edc-af49-a48bc77f3e11`. A subsequent helper command began while the runner was ending; existing started IDs were not resent. Final observed receipt `1788765301733-1babd4b1-283b-45c4-8c52-2862b0167dd0` showed a new Puzzle 1/3 at Turn 2/10, score 630, balance 44. Resource exit was normal (`1788765304127`). No Book completion claim.

### C-10 bounded continuation

- Fresh C-10 readiness was verified by `ready` receipt `1788765581.6005878`. Normal saved resume used PLAY `1788765605682-13098189-bae0-4caf-bdfb-6dc71b05614c`, Volume 9 selection `1788765607072-b4be7378-3995-4ba5-a6bc-02f07337e880`, OPEN THE BOOK `1788765608469-c0bfb265-487e-4578-86b6-238163ad7239`, and CONTINUE CURRENT `1788765615172-1576b432-2be5-45f0-9bc0-b6208ac99dd6`. Settled active snapshot `1788765637722-75ed4c05-edb7-4640-9d05-804d7f13e40b` showed Level 3 Puzzle 1, Turn 2/10, score 630/4,000, 44 coins, and Morning Edition, Op-Ed Column, Sports Section, Golden, and Emerald retained.
- Public helper placements were confirmed before/after: 2@r5c2 (`1788765645253-270ac9c5-1f5f-45cd-91f6-bad07b858f6a` → `1788765647305-d782af8b-8864-46c9-8f68-300429d48cb1`), then 5@r3c1, 6@r3c2, 7@r5c5, 2@r4c5, 8@r9c2, 8@r8c7 through final `1788765726874-5dd46705-aebe-40f8-a776-1603453b8ec8` (Turn 4/10, score 2,050). A second helper pass confirmed 9@r4c2, 5@r5c6, 4@r6c6, 6@r9c9, 5@r4c7, 1@r6c4; final `1788765746302-b4a3e460-b2da-4e5f-ba5b-d42de7a09d84` showed Turn 5/10, score 3,210/4,000, with further public deductions visible.
- Snapshot `1788765767119-5c927b23-8281-49ba-9160-95ebc280bf8a` showed `Puzzle Complete`, settled 4,250/4,000, six unused turns, and 44 coins. Cash Out was issued once by observed coordinate; receipt `1788765785361-4251e666-35e7-406e-9711-107902382593` remained pending at session stop and was not resent. No completion/unlock claim; final settled post-cash-out state remains for root to inspect.

### Read-only marker/scoring evidence review

- C-09 native AX at `1788765264058-f6b59681-31a5-491f-a11a-dab254bc7acb` and subsequent Level 3 receipts identify the persistent marker positions exactly: `Row 1, column 1, number 9, given, Golden Marker` (R1C1) and `Row 9, column 8, number 3, given, Emerald Marker` (R9C8). The marker picker AX at `1788765196562-731cd811-3198-432c-bfca-62987c866d66` also exposed the occupied R1C1 Golden button.
- Sports Section was visibly active in native C09/C10 AX and PNG: HUD button label `Sports Section. Line Clears gain +25`. In active Puzzle 1 snapshot `1788765296615-3cab4d10-419e-46e9-b12f-4a2a94fe84f4`, the settled UI visibly displayed `+25` at the score header while Sports Section was equipped. The evidence confirms the active bonus presentation; no separate textual per-clear ledger was exposed, so per-line attribution is not claimed beyond this visible +25 credit.
- Accessibility reconciliation: ordinary Level 3 run-plan receipt `1788765257720-dd6789a9-01e8-4f15-83b0-763885e6710e` exposes one public combined label: `Run plan: Easy, Easy but hard, then Boss. Current stop: Easy. Tik Tak. Power: Four minutes for the whole Puzzle. Miniature grids illustrate the route.` Thus the actual Boss name (`Tik Tak`) and power are present in the AX label.
- C-09 SOLD-offer count is one `Button` per sold offer (no duplicate controls): Golden Marker only at `1788765144476-7f328c1e-1321-4776-9519-328fbf59e1dc`; Sports Section only at `1788765190206-79bd9e6e-c4a0-44ca-8e39-5fa0718f83a4`; Sports Section + Emerald Marker at `1788765196562-731cd811-3198-432c-bfca-62987c866d66`, `1788765225079-6015b6b6-f1d3-4999-aba5-55ae032576dc`, and `1788765246233-08fe2184-cac7-4573-92fd-b63368b5a326` (two sold Button labels each).

### C-11 bounded continuation

- Fresh ready receipt `1788766499.321394` was newer than the C-11 resource start. Normal resume used PLAY `1788766540861-68db8e95-377c-42fc-8c75-64f010ed706c`, Volume 9 selection `1788766563154-a7443c26-dde2-49c9-ad54-60095f7ba258`, OPEN THE BOOK `1788766577800-553d9251-9e69-48fb-8725-9cf3ce24e28e`, and settled win snapshot `1788766584755-f700a38a-d912-42a3-9e19-e4dfd7c70e5c`. The native completion UI showed `4,250 / 4,000`, 6 unused turns, and total payout 15, confirming the iPad-style base/details layout.
- Cash Out receipt `1788766592089-330a613b-720e-4c2c-b13b-fe8d8478fa74` showed the normal Shop at settled 59 coins. Chose visible scaling Bookmark Paper Route (+2 coins on every Puzzle win payout) for 5 coins; purchase/equipped proof `1788766608437-c691cb45-97cb-4ef0-90c6-04c7e60c534e` showed HUD Paper Route and 54 coins. Continued normally to Level 3 Puzzle 2 (`1788766624442-83669c0a-bb66-4914-9bdc-d447bfcf836e`), target 6,000, Turn 1/10.
- Public helper confirmed 12 normal deductions: 4@r1c3, 6@r4c2, 6@r8c1, 5@r3c5, 6@r3c9, 8@r1c6, then 1@r3c1, 9@r3c7, 4@r2c4, 9@r2c2, 7@r1c7, 3@r1c2; final `1788766668036-0fef9487-83d6-4251-babd-9cb49188c6da` showed Turn 3/10, score 800/6,000, and further legal public options. Session stopped safely before further commands; no Book completion claim.

### C-12 bounded continuation

- Fresh ready receipt `1788766924.024533` was newer than the C-12 resource start. Normal resume used PLAY `1788766945349-ef2da195-9b87-46c8-b609-cc9c1bbda022`, Volume 9 selection `1788766960247-385c4d9e-cff1-4fef-bca0-d2d875b3a376`, OPEN THE BOOK `1788766972559-c6d62969-eeba-4477-9b1c-8daa9ef51b94`, and settled resume `1788766979165-a5c061ad-4648-46ad-b108-e15cb1c627f2` showing Level 3 Puzzle 2, Turn 3/10, score 1,730/6,000, 54 coins, and all four Bookmarks/markers retained.
- Public helper confirmed 15 additional deductions through `1788767038999-8567941f-ad11-4e48-b542-3d1890545db9`: 7@r2c1, 6@r1c4, 1@r1c8, 1@r2c5, 9@r4c8, 4@r8c6, then 3@r4c1, 7@r4c3, 7@r9c2. Intermediate settled helper final `1788767023688-e70126a0-216c-458e-9c68-a8882ee6e97c` showed Turn 5/10, score 2,900; root later observed settled Turn 5 score 3,690.
- Final snapshot command `1788767067902-3f5440dc-a5d9-4378-864c-622024db58da` was pending at stop and was not resent. Session ended normally; no timed Boss was started and no Book completion claim was made.

### C-13 bounded continuation

- Fresh ready receipt `1788768044.392158` was newer than the C-13 resource start. Normal resume used PLAY `1788768066467-3a8403ad-8a82-4334-9e99-50a39251b2d4`, Volume 9 selection `1788768082262-ee00e7d6-c6e0-41f4-b120-b2039dbe64ee`, OPEN THE BOOK `1788768096057-0da4e3ef-0dba-4acc-bddf-10ff8b29b210`, and settled resume `1788768102198-fe9486c5-f942-4950-87ea-9f0a16936c7a` showing Level 3 Puzzle 2, Turn 5/10, score 3,690/6,000, 54 coins.
- Public helper confirmed 15 placements through `1788768141809-afe7fdb2-2488-410f-ac8f-72368245be46`; the settled completion snapshot `1788768155936-d58e6f76-cff3-49da-99df-09d1cfc7d6fa` showed Puzzle Complete, 6,200/6,000, 4 unused turns, Paper Route +2, total payout 16. Cash Out reached the next Shop at 70 coins (`1788768164180-7f2c5384-bdf7-454f-9044-e102a92d0f52`).
- Bought Copper Marker (+3 coins for each Line or Box completed by the placement) for 5 coins; purchase details `1788768173071-908ef589-2860-4086-ab59-c612841ab881`, sold/equipped and 65-coin Shop state `1788768191797-96395bba-dafa-4d2e-a193-cfbfbf652655`. No timed Tik Tak Boss was started; no Book completion claim.

### C-15 bounded continuation — Level 3 Tik Tak Boss

- Fresh C-15 readiness receipt `1788768656.393825` was newer than the supervised resource start. Normal resume used PLAY `1788768676689-d825b57c-9c07-48c7-8c5f-dd7361e3f37b`, Volume 9 selection `1788768694374-853a56be-caee-4240-8900-5d9948aafa9e`, and OPEN THE BOOK `1788768708679-39ea471a-2558-47a0-948f-c2f2dbda563c`. Tik Tak briefing `1788768715073-8314535f-8869-4cc1-9a45-b0649778a59c` showed the four-minute Boss, 61 coins, and five Bookmarks/markers.
- Started the timed Boss normally at `1788768723131-903b99b1-6bae-4bf6-b9f6-67c450a446e4`; public AX identified Copper Marker at Row 9, column 9, and Golden R1C1/Emerald R9C8. Public deductions confirmed 9@r9c6, 7@r4c4, 1@r3c6, then 8@r6c6, through `1788768760926-8e1c9cb9-a28e-4f35-a457-41645339a31e`. Normal End Turn receipts `1788768747340-13885403-e4f9-4228-808a-710e88c04a4b`, `1788768768707-63f53bba-cce6-4b81-9acf-872ab7108697`, and `1788768784555-035807b0-8fac-4103-8b7c-51518278b4ac` advanced to Turn 4. Audit correction: **no Toss was spent**. `1788768802329-69d53e38-9cca-4997-b703-9135ebbb782d` tapped Toss without a selected card and prompted `Pick one number to Toss`; `1788768809570-14fbe092-a219-4910-b76c-909c9dd0bd66` selected 2, but the next action was End Turn, not Toss. The allowance stayed 4. This was a player-workflow error, not a confirmed app bug.
- Final public checkpoint `1788768832345-051f3656-f0db-4490-bcaa-c0c2d2cc39ec` showed Tik Tak Turn 5/10, score `900/8,000`, and 132 seconds remaining at capture. No win/loss or Book completion is claimed. Root’s supervised session later exited cleanly at resource timestamp `1788768897797`; 27 player commands completed with no unresolved command. I stopped after the safe checkpoint because the visible hand had no further public deductions and the timed Boss was consuming its bounded window; no stop UI receipt was issued.

### C-16 through C-19 — root faster-harness pilot and normal restart

- C-16 reopened the saved timed boss and stopped at 38 seconds remaining,
  no moves made; this was preparation, not throughput evidence.
- C-17 verified two real Tosses (4→3→2) and End Turn 5→6. The previous attempt
  timed out; root visually checked `1788770296190-2a8c9fe9-1650-4c0c-bcb0-f9f5b4522db5`:
  Book over, score 1,000/8,000, Out of time. Previous 8/27 is historical,
  not a live saved run. Do not claim a completed Book.
- C-18 opened Volume 9 normally to a new Level 1 attempt; no save edits or
  QA bypass. The new batch's `isHittable` guard rejected its first placement
  before either tap, with no grid change. Root corrected this harness-only
  false negative to the existing normal coordinate-tap mechanism.
- C-19 passed: 10 public-deduction placements in 19.181 seconds, spanning
  Turn 1→2, receipts `1788770763546-6c918cfe-c923-490a-b5c0-c5cd78b5c1e1`
  through `1788770781146-94b86946-17fd-4121-9952-0dd916a22a51`.
  Final visible checkpoint `1788770782933-bef8ed29-ae69-4567-a213-b491227cd14c`:
  Turn 2/10, banked 330/1,000, +320 queued, Hand 2/7, 4 Tosses, 5 coins.
  Resource exit 0; 18 commands/28 weighted units, peak runner 55.83 MiB,
  normal pressure, no unresolved actions. App save preserved by shutdown.
- Resume this fresh run with the tested `visible-turn.mjs puzzle C` loop,
  not per-tap model deliberation. Root still exclusively owns native launch;
  wait for START. Use intentional shop/buff/clue strategy at checkpoints.

### C-20 bounded continuation — optimized public puzzle helper

- Fresh ready receipt `ready` had timestamp `1788771015.175354`, newer than the C-20 resource first timestamp `1788771007031`. Normal public navigation used PLAY `1788771042170-0eade0c9-4b11-41f9-b47d-760b3b27e6de`, shelf snapshot `1788771047279-cb0a4aca-5676-41d2-bfc1-85c26eb0ca35`, Volume 9 cover selection `1788771148486-c64815fa-8a57-437e-a5e4-ece49349e9e9`, selected-cover confirmation `1788771154569-52a4476e-a8dd-4ce3-bc56-259fae11af70`, and OPEN THE BOOK `1788771161342-8bf826a2-9aa2-4343-97ea-30232a8a6f92`. Active-board snapshot `1788771167157-6731235c-158c-4f0b-995f-6172eae30859` showed Level 1 Puzzle 1, Turn 2/10, score 330 with 320 queued, 5 coins, 4 Tosses, and prior placed cells preserved.
- Tested public helper confirmed five place-card actions: 7@R7C1, 2@R1C3, 9@R9C8, 9@R7C6, and 6@R4C3. Exact receipt pairs were `1788771174691-b5003f32-a077-4ebd-a2a9-dd84c9709a05` → `1788771175692-8732f177-4f8c-450e-899e-03ac4fa50def`; `1788771175692-8732f177-4f8c-450e-899e-03ac4fa50def` → `1788771177488-e04926db-6647-43d2-99ad-344cc2cfe98f`; `1788771177488-e04926db-6647-43d2-99ad-344cc2cfe98f` → `1788771179273-3e137b87-4ec3-4c88-8b04-379c2cdddb0f`; `1788771179273-3e137b87-4ec3-4c88-8b04-379c2cdddb0f` → `1788771181271-2679a263-04e7-414a-8e7e-2fc5981d9eab`; and `1788771181271-2679a263-04e7-414a-8e7e-2fc5981d9eab` → `1788771183260-1ec36cf4-116c-4a44-a274-30c8b8e74b83`. No Toss or End Turn was needed.
- Final settled snapshot `1788771185258-09615610-6bc3-425f-ba23-f47626191e6e` showed Turn 3/10, score `740/1,000`, hand 8,7,2, four Tosses remaining, and additional public options. Helper reported 28 weighted actions and 171.7 seconds elapsed from ready; it self-stopped normally. No win/loss or Book completion claimed.

### C-21 — root batched navigation and first fresh-run win

- Root resumed the same Volume 9 save using normal PLAY, the visually verified
  bottom-shelf cover, and OPEN THE BOOK. No hidden state or save edits.
- Public deductions placed 2@R4C1, 7@R4C2, and 8@R6C1 at receipts
  `1788771514900-b2db9137-4974-4c50-b27c-745093f7fa10` through
  `1788771518682-ec58c5ce-dc2d-494d-8cf4-afcec83cf3dd`.
- The delayed win transition made the next proposed placement stale; the
  driver rejected it instead of tapping stale coordinates. Settled checkpoint
  `1788771522028-ecf8447e-492b-48e1-a3ba-5d8772aef9f6` confirms Puzzle Complete,
  1,210/1,000, seven unused turns, payout 12, five coins before Cash Out.
  The helper's nonzero exit is a transition/precondition stop, not a game loss.
- Resource supervisor exited 0, peak runner 54.88 MiB, normal pressure,
  no pending commands. 14 commands/18 weighted actions in 48.99 seconds;
  actual action/observation wait 11.07 seconds. Fresh attempt has cleared
  1/27 puzzles; no full Book completed. Next: Cash Out and choose scaling
  offers from the actual Shop before continuing.

### C-22 — larger bounded batch, Shop choices and second fresh-run win

- Root alone owned the simulator. After the previous runner was terminal,
  the external driver was rebuilt with a 120-weighted-action ceiling, while
  all memory thresholds, 240/270/300-second guards, and automatic shutdown
  remained unchanged. Public helper budget is 108 actions / 180 seconds.
- Cash Out restored 17 coins. Actual Shop checkpoint
  `1788771832513-8d12d6cd-d576-4112-82db-1bcf8ef090d2` offered The Sunday
  Supplement (7, x2 normal/x3 Boss) and Paper Route (5, +2 per win). Bought
  both, verified sold states and equipped HUD, leaving 5 coins. Prioritized
  scaling and early-run income over unhelpful immediate Marker purchases.
- Continued to Easy but hard, Level 1 Puzzle 2; next Boss publicly identified
  as The Critic. Played normally without taking the skip clipping.
- From active board `1788771919426-f1cd36d4-7bdd-4699-9de4-43b32a83c89e`,
  18 confirmed deductions took 33.731 seconds, reaching Turn 4. Settled win
  `1788771956090-8c131d9a-cc81-49de-b094-079229ceab3c` followed at 36.429 seconds:
  Puzzle Complete 2,040/1,500, 7 unused turns, Paper Route +2, payout 14.
- A 19th `place-card` transport succeeded but its placement did not: the
  results transition exposed `puzzleNotPlayable`. Do not count that action
  as a confirmed placement. Root visually verified the raw toast (UI-20).
- Whole session: 178.75 seconds including resume, Shop and inspection;
  37 commands / 56 weighted actions, runner peak 58.49 MiB, normal pressure,
  no pending commands, supervisor exit 0. This validates real work past the
  historical 40-unit cap, not the entire 120-unit maximum or unlimited safety.
- Current saved run: 2/27 puzzles complete, waiting at Cash Out. No full Book
  complete. Next cash-out should add 14 to the visible 5 coins, then buy only
  sensible current offers before starting The Critic.

### C-23 — first Boss in progress, normal purchases retained

- Cashed out Puzzle 2 to 19 coins. Shop receipt
  `1788772280847-4333dc0e-ba34-4ba8-93c4-288c25a81b79` was visually checked.
  Bought Late City Final (+1 Turn each Puzzle, 7) and Golden Marker (+100,
  6), leaving 6 coins. Chose R5C5 on the ordinary public placement map;
  active-board AX confirms Golden Marker at that exact square.
- Boss briefing `1788772351172-8d966c32-4d89-42bd-ace9-6e2001d7bba2` showed
  The Critic (wrong-placement penalty doubled). Started with Sunday
  Supplement, Paper Route, Late City Final and Golden retained.
- Eight public-deduction placements confirmed through
  `1788772374499-215fb1df-f946-4c25-9d9c-86b676e0ec6d`. Three real Tosses
  decreased the allowance 4→3→2→1; one End Turn advanced 1/11→2/11.
  Final public receipt `1788772380897-33a1be5f-0b92-4bd7-bcf9-43037a830d18`:
  990/2,000, Turn 2/11, 6 coins, R5C5 Golden still empty.
- Supervisor exited 0 at 1788772383354 with normal pressure and 57.21 MiB
  peak runner. It ended after 40 completed weighted units, earlier than the
  current source ceiling. Cause under investigation; no resource-stop claim.
- Proposed End Turn `1788772382361-4c5a9401-cd9c-487d-8099-a4815ba5092d`
  had neither a started journal nor a receipt after authoritative termination.
  Preserved unexecuted in `/tmp/numberclub-c23-unstarted-ucpDgx/`; never resent.
  Next session must freshly observe current turn/hand, not assume End Turn ran.
- Book remains 2/27; first Boss not yet won. No run reset.

### C-24/C-25 — failed strategy, then normal rewarded recovery

- C-24 restored The Critic at 990/2,000. One more confirmed 7@R1C9
  completed the row and brought the settled score to 1,890/2,000.
- The helper then exhausted Turns 4–11 with the identical full hand
  `[9,6,4,9,3,2]`. End Turn retains unused cards; this was a testing-player
  strategy error, not a confirmed game defect. Terminal evidence:
  `1788773253067-53144479-0c47-480e-9413-b9ae104d41aa`.
- C-24 exited 0, peak runner 54.83 MiB, normal pressure, no pending commands.
  Its explicit-stop diagnostic confirmed the current guarded runner version.
- C-25 reopened the same Volume 9 normally. Optional test-ad loading became
  an enabled Watch action at `1788774039279-216004ae-6264-4cac-9930-da37ad9de277`.
  Watched the clearly labelled Test mode ad; did not click Get/install.
  `1788774120029-d2248891-21a9-44fe-8d1f-c131cf9760d9` showed Reward granted
  and enabled Close; dismissed that actual control.
- Recovery checkpoint `1788774148169-aa431309-4293-4b48-9ea0-210ee4f66cf8`
  confirms Turn 12/14, score 1,890/2,000, identical board/hand/Bookmarks,
  6 coins and zero Tosses. This proves the normal rewarded recovery, not a win.
- A proposed R2C3=3 calculated guess was refused by preflight before queuing
  because the normal command window had expired. It did not execute.
  C-25 subsequently exited 0 by its deadline; no restart based on observation
  timeout. Resume must inspect fresh state before any move.

### C-14 bounded continuation

- Fresh ready receipt `1788768351.965351` was newer than the C-14 resource start. Normal resume used PLAY `1788768380456-f51ba67a-2f84-45ca-bf59-d424b8dccb24`, Volume 9 selection `1788768396845-801eab71-6f62-4b65-999b-45e3eb9594ea`, and OPEN THE BOOK `1788768410622-b2b02b17-6704-4c03-a061-40620fe2930c`. Shop snapshot `1788768417352-18af9b4b-2f01-47ab-bde3-e2df26219752` showed 65 coins, Help Wanted affordable for 4 coins, and Copper Marker sold.
- Purchased Help Wanted (+1 hand size) normally: details `1788768437211-fb4b32a0-ab11-40d3-81e0-bf5537c55537`, equipped/sold proof `1788768447136-30704133-cec5-46b0-b50e-1a354c88e1a9`, balance 61. Continued to the Level 3 Boss briefing `1788768457244-ab2d1a5d-c8f8-4bb2-a4d7-1fb11a1f963e`, which visibly identified `Boss encounter: Tik Tak. Four minutes for the whole Puzzle`; did not start the timed Boss late in this batch. No Book completion claim.
- C-11 reconciliation (preceding batch): that 800 was an immediate score-animation capture. Read-only STOP receipt `1788766727911-83994b7a-0cde-402c-9013-5639c27f942d` verifies settled score **1,730/6,000**, Turn 3/10, 54 coins. The driver recorded 37 player commands plus root's stop, 38 total, excluding initial readiness; supervisor exited 0 and shut down C. Runner peak 57.71 MiB, pressure normal.
- C-12 reconciliation: final completed receipt `1788767040340-20584d3c-f3ed-4cbf-8dc4-d0cd511f61e7` selected a card after the preceding confirmed placements. Current score is **3,690/6,000**, Turn 5/10, 54 coins. Exactly 40 commands completed, excluding ready; runner peak 60.66 MiB, pressure normal, supervisor exit 0. Unstarted placement `1788767041661-275e1a38-ff3b-44ce-8403-04dd64e272f2` and snapshot `1788767067902-3f5440dc-a5d9-4378-864c-622024db58da` were preserved in `/tmp/numberclub-c12-unstarted-Fm88wj/`, not replayed. Next batch must reopen and observe normally.

### C-26–C-36 reconciled rapid continuation

- C-26 settled Level 1 Boss/The Critic at 2,490/2,000 in
  `1788774298589-93977d6c-50da-4582-b0ff-844b657a5e5d` (3/27). C-28 settled
  Level 2 Puzzle 1 at 2,460/2,000 in
  `1788774605607-1d08e831-2c49-4233-bfcd-fecf1daae42f` (4/27). Visible
  purchases were Morning Edition (4), Puzzle Corner (7), Copper Marker (6),
  R5C4, and Litmus (4).
- C-30 settled Level 2 Puzzle 2 at 3,700/3,000, 7 unused turns, payout 14:
  `1788775152950-89bee4e2-e008-4183-b81e-4adef78aecc2`; Shop follow-up
  `1788775211490-4fca9684-8c45-4fb3-b425-d4dac010b27f` showed 23 coins.
  C-29's 2,180 was an intermediate receipt, not a loss.
- C-31 settled Level 2 Boss/The Deadline at 5,680/4,000, 7 unused turns,
  payout 13 (`1788775628945-b22cb973-a001-40dd-b4db-a46135ca08df`), cashed
  out 16→29 (`1788775631198-13d63209-dc7d-4810-ab14-c2300b4b2356`), then
  settled Level 3 Puzzle 1 at 5,060/4,000, 8 unused, payout 15
  (`1788775663222-42e6a9aa-63b4-4a57-a726-093bd0ca6069`). Cash Out remained
  pending; no full Book or unlock/return proof is claimed. Current honest
  progress is **7/27 puzzles, zero full Books** before C-32.
- Resource reconciliation: C-26 56.9s/26 weighted actions, C-27 46.9s/14,
  C-28 201.2s/87, C-29 240.2s/43, C-30 240.1s/12. C-29 and C-30 had roughly
  59s and 164s idle after their last useful UI receipt before wall expiry;
  C-31 stopped explicitly after its settled snapshot at 145.885s active/77
  weighted actions (57 commands), with 59.60 MiB peak and normal pressure.

- C-32 resumed at the Level 3 Puzzle 1 Cash Out, settling 29→44 coins in
  `1788775853287-be7662c0-b77d-4763-8874-b97b233a76fa`, sold Morning Edition
  for 2, and bought Rolling Presses for 7 plus Lucky Dip for 3 (36 coins).
  Level 3 Puzzle 2 settled at **13,320/6,000**, 8 unused turns, payout 16:
  `1788775981789-22ce2633-2c78-418a-80a5-e1cf552a55c6`. Cash Out to 52 coins
  was `1788775983805-c8b165a5-eef0-42f8-9d87-85018e4e14e7`; Continue entered
  Level 3 Boss/The Editor with one fewer hand card at
  `1788775985803-9d9ac9e2-6218-45b6-8993-bb62f5b837bf`. Boss start and
  confirmed 1@R8C6 led to Turn 1/10, score 0/8,000, hand 7,4,1,2 at
  `1788776039822-66e2f0cf-114f-4e79-ac22-7630519cc546`. A late 9@R3C4
  attempt coincided with target-reaching animation; it was not confirmed, but
  no error toast or failure was observed. Current honest progress is **8/27
  puzzles, zero full Books**; no unlock/return proof exists.

### C-50 continuation

- C-50 won Level 9 Puzzle 2 at **671,580/384,000**, 4 unused turns, payout 19
  (`1788779830284-024a9815-5e67-4dca-85f2-15b90707f284`), cash 285→304 with
  no further purchases. The final boss, The Budget Cut, started at target
  512,000 (`1788779838427-e5c6ca10-8452-4fef-a4ee-9c5859578c77`), then remained
  partial at **18,090/512,000**, Turn 4/10, Toss 0, hand 7,2,9,7,2,6
  (`1788779879085-5938f259-8672-41ee-800b-18794b0ed704`). Current honest status
  is **26/27 puzzles, zero full Books**; no unlock/return proof exists.

### C-51 — Volume 9 completed

- C-51 completed **27/27 puzzles**, **9/9 levels**, and **9/9 bosses** in
  Volume 9, defeating The Budget Cut. The fully settled native congratulations
  page followed the win directly without Shop (`1788780062472-ae717b1c-744e-4e7a-b794-b86ec5176176`).
  Fresh AX confirms `BOOK COMPLETE`, 9/9, Obstacle II ready in this Book, 320
  coins, and only Close Book (`1788780113736-fe966eac-e110-4fe0-86ef-bbe25afa2ebc`).
  Final Peek selection 2@R2C5 (`1788779965920-eeff88f0-0d9d-404d-8310-42f3d2372be1`)
  was followed by normal deductions. This is the first completed Book; **11/12
  Books remain**.

### C-52 — completed-Book obstacle unlock visibility

- Public Volume 9 selection AX confirms Obstacle I and Obstacle II unlocked,
  while Obstacle III–IX remain locked (`1788780250207-5cd7bf24-e9fc-4157-a7cd-9602ac40d06f`).
  The separate cross-Book selection check remains pending.

### C-53 — cross-Book unlock isolation

- Selecting Volume 5 via its actual middle cover produced fresh AX showing
  Obstacle I unlocked and Obstacles II–IX locked
  (`1788780557124-d028e309-9d37-451f-a283-4e2db6061fd0`). After returning,
  the full shelf showed Volume 1 and Volume 5 locked on 2–9, while Volume 9
  alone showed its colored 2 tab and locks 3–9
  (`1788780585165-3c729737-1467-4b4a-9bdc-684e15f76c72`). This proves scoped
  per-Book unlock state with no visible stale unlock leak. A return tap during
  transition produced no selection and no unlock mutation; it is not classified
  as a new game bug.

- Final Volume 9 reselection again showed Obstacle I and II unlocked and III–IX
  locked (`1788780634445-aaa00306-f5e2-4fef-8941-78e8d59842bf`). The later
  top-cover attempt did not prove Volume 1 selection and is not labeled as such.

### Fast all-engine coverage

- A fast verification passed **251 tests, 0 failures** in 90.941s (92.95s wall),
  including the full 2,052 Book×Boss×Obstacle matrix across all 12 Books and 9
  obstacles (`/tmp/numberclub-fast-all-engine-20260907.log`). This is engine
  coverage, not normal-player completion: only Volume 9 is complete (**1/12**).
  Future checks should reuse the engine matrix and focused app matrices, with
  bounded native checks for uncovered touch/timing behavior; the remaining 11
  Books are not marked complete.

### Final fast production-start/app validation

- Production-start validation passed 108 fresh starts plus 324 turn-rule/save-
  preservation checks in 3.962s (6.54s wall):
  `/tmp/numberclub-fast-108-starts-final-20260907.log`. The app gate passed
  54/55 checks in 167.164s (235.75s wall), covering progression (3), bookstore
  obstacles (10), living Book (6), themes (9), scenes (8), routes (7), and
  briefing (10): `/tmp/numberclub-fast-books-obstacles-app-20260907.xcresult/log`.
  The sole failure is an OCR false negative on Overthinking 375/obstacle 9;
  manual full-PNG inspection confirms the plaque is correct. A further ROI
  adjustment caused another false failure and was reverted. Normal completion
  remains **1/12**.

### Native frontend pass — dedicated iPhone 17 Pro

- Bounded Release checks covered rack navigation and selection/return for
  Volumes 1, 5, and 9, endpoint/banner separation, RunInfo marker map,
  Evening Edition readability/Sell 2 label, Settings/Achievements/How To Play,
  and physical End Turn. Video: `/tmp/numberclub-native-frontend-endturn-20260907.mov`.
- Volume 1's old Critic save reopened at Level 1 Puzzle 3, Turn 10/11, score
  330, hand 7. End Turn advanced 330→630; the next End Turn failed normally at
  630/2,000 with ad and End Book visible. Ads were not used; no full-playthrough
  claim follows.
- RunInfo Crimson ×4 coordinates and Evening Edition were readable. RunInfo and
  Settings scrolling did not move through this control method and remain
  **UNVERIFIED**, not a confirmed bug. Locked Obstacle IX copy/AX/Close fix is
  verified in Release: distinct title, LOCKED, Close obstacle details, power,
  and requirement elements; copy reads “Finish Obstacle VIII in this Book to
  unlock Obstacle IX.” Close was hit and dismissed the popup.
  Full Books remain **1/12**.

- Inspected scoring-detail frames at 8fps (9.5–12.5s): Turn points 0, Evening
  Edition +300 with actual Bookmark +300 tag, BANKED +300, and score 330→630;
  no source-label overlap (`/tmp/numberclub-native-frontend-scoring-detail-20260907.png`).
  Broader 1fps contact sheet: `/tmp/numberclub-native-frontend-endturn-contact-20260907.png`.
  Focused native obstacle popup suite passed 12/12 in 16.214s
  (`/tmp/numberclub-native-popup-regression-20260907.xcresult`). Release rebuild
  succeeded at `/tmp/numberclub-native-popup-release-20260907.log` and the
  reinstalled native popup copy/AX/Close hit passed; no frame-pacing or haptics claim.

### C-34 — Boss and Level 4 continuation

- C-34 settled Level 3 Boss/The Editor at **10,890/8,000**, 7 unused turns,
  payout 17 (`1788776382002-480bcf5f-17dd-45f3-815b-0fb347a6ce6a`), then
  cashed out 52→69. Golden Marker was bought and placed at R5C6
  (`1788776433806-7608b00c-d210-4452-a64f-0cce5c868148`). Public AX
  `1788776503071-bfbe72be-9679-48e9-ae08-b596fa198dd1` confirms Copper R5C4,
  Golden R5C5 and R5C6, and Emerald R5C7. After a reroll, Puzzle Corner was
  sold for 3 and Letters to the Editor bought for 7; Emerald placement was
  confirmed at R5C7 (`1788776498301-7d091796-6ee3-4f5c-9b8b-e90e22e9605e`),
  leaving 50 coins.
- Level 4 Puzzle 1 settled at **12,690/8,000**, 8 unused turns, payout 18
  (`1788776531754-235bc264-8985-42ba-9369-06632cfa01af`), reaching **10/27**.
  It was not cashed out in this batch. C-33's externally interrupted expiry
  produced no gameplay evidence and is not counted. No full Book or
  unlock/return proof exists.
### C-35/C-36 continuation

- C-35 settled Level 4 Puzzle 2 at **19,890/12,000**, 7 unused turns, payout
  18 (`1788776677183-cbc21544-0887-4760-9145-120e45cbd5a5`), cashed out 68→86,
  then settled the Fog Boss at **20,880/16,000**, 7 unused, payout 20
  (`1788776720620-e6a05ba8-abdc-4f4f-a848-359846b249d4`). C-36 cashed out
  86→106 and settled Level 5 Puzzle 1 at **40,290/16,000**, 7 unused, payout
  22 (`1788776935784-d70689cd-8c5b-4dde-add9-599f893a2a41`), then reached
  Level 5 Puzzle 2 Turn 4/10, score 20,730/24,000, hand 7,1 at
  `1788776991333-88548b19-0b04-4e87-9504-8f9ad15a8a29`. No purchases were
  made; all four marker positions and five Bookmarks were preserved. Both
  sessions ended by explicit STOP with no pending actions. Current honest
  progress is **13/27 puzzles, zero full Books**.

### C-37/C-38 continuation

- C-37 won Level 5 easy-but-hard at **34,590/24,000**, 6 unused turns, payout
  21 (`1788777069159-62b5f060-4793-49c5-b6ac-ff962ae983c6`), then cashed out
  128→149 (`1788777071073-29e97d01-7999-4f34-bc04-6d9c337c53db`). No purchases
  were made, reaching **14/27**. The Deadline followed at 12,600/32,000,
  Turn 4/8, Toss 0, hand 9,3,1,2,6,4 in
  `1788777103558-7db21531-cb1b-42c7-9834-7e766b1b091e`; Litmus/Lucky Dip
  were retained for the next play.
- C-38 only opened the Litmus popover before compaction; it made no placements
  and added no puzzle count. The session timed out safely. UI-23 source review
  passed, but native guard/test verification remains pending. Current honest
  status is **14/27 puzzles, zero full Books**; no unlock/return proof exists.

### C-39 continuation

- C-39 won Level 5 Boss/The Deadline at **50,040/32,000**, 2 unused turns,
  payout 17, with 149 coins before cash-out:
  `1788777641724-f0f3c6a1-cabf-465f-8694-77d65cb5cbe6`. Public Litmus use
  showed 6 matches (`1788777503557-2b48a32a-b707-438a-8596-beb95059fc0a`);
  normal 6@R6C4, 4@R6C5, and 2@R6C6 placements completed the clear
  (`1788777555318-28a9a27d-a230-4ebe-9173-cd2403e7efb`). Lucky Dip drew 1,5
  (`1788777585873-4c75942a-b865-4e39-8023-d07d70979e2f`), then 5@R4C9 reached
  29,880. Remembered public Litmus hints enabled 3@R5C4 and 9@R5C5, confirmed
  by `1788777633976-1bd23b5e-efb3-468f-865e-3d9dc7510b60` and
  `1788777636142-6716a4ad-ca28-4daf-af7f-fdb279c52ef5`. End Turn produced the
  settled win. Current honest status is **15/27 puzzles, zero full Books**.

### C-40 continuation

- C-40 won Level 6 easy at **32,790/32,000**, 7 unused turns, payout 22
  (`1788777742569-88726998-c200-4027-9cf8-da1899da9ec5`), then cashed out
  166→188 (`1788777744680-605ae077-bb33-4fd4-b41f-31ac9ed5101b`). Sold Local
  Gossip (+2) and bought Front Page Splash for 7, leaving 183 coins. Level 6
  easy-but-hard remained partial at 36,180/48,000, Turn 4/10, 4 Tosses, hand
  1,1,7,4,7,2 (`1788777800590-3940db8d-93fd-441b-aba8-b1c9309904fc`). The
  batch ended cleanly at 105 weighted actions/118s. Current honest status is
  **16/27 puzzles, zero full Books**; no unlock/return proof exists.

### C-41/C-42 continuation

- C-41 won Level 6 easy-but-hard at **90,180/48,000**, 6 unused turns, payout
  21 (`1788777877228-b0873831-8185-4d40-8a9f-b3e2f497fe10`), cash 183→204.
  C-42 won Level 6 Boss/The Critic at **71,180/64,000**, 5 unused turns,
  payout 20 (`1788778075345-83919618-730f-4e8c-bf95-96032938d2fa`), cash
  204→224. A public two-candidate guess selected 1 at R8C2 and was wrong
  (−100; `1788778044369-e29579ac-825b-4085-8431-902ca06d275f`); visible
  feedback then established 1@R8C8 (`1788778046325-b817299c-ebc4-47ca-9b2e-ed4919d8c8e0`),
  after which normal deductions chained to the settled win. Current honest
  status is **18/27 puzzles, zero full Books**; no unlock/return proof exists.

### C-43/C-44 continuation

- C-43 won Level 7 easy at **89,280/64,000**, 7 unused turns, payout 22
  (`1788778311592-5cc28ac3-3842-480d-a69f-32e902ab6232`), cash 197→219.
  Double Down and Second Print were used normally, with public receipts
  `1788778263409-cc67a28b-6c81-443b-bc6a-11ad2e64d4e7` and
  `1788778268057-de6b39f5-3a72-4d61-a7ae-4950582dd3da`. Public receipts show
  197 coins after the visible Sapphire placement at R5C8 and purchases/rerolls;
  no unlisted spend is inferred from arithmetic.
- C-44 won Level 7 Puzzle 2 at **134,640/96,000**, 6 unused turns, payout 21
  (`1788778428748-d28c3e92-645e-4689-a24a-2fcd2c26a4b7`), cash 219→240.
  Peek was bought for 3, leaving 237 (`1788778436160-a0a97255-9f7a-4732-83b6-227d5e7f7688`).
  The next puzzle remained partial at **97,200/128,000**, Turn 6/10, hand
  4,4,9,9,9,4, with no Toss spent (`1788778496075-7d2def8f-ae17-4630-9a07-d8e32c46e6aa`).
  Current honest status is **20/27 puzzles, zero full Books**; no unlock/return proof exists.

### C-45 continuation

- C-45 settled Level 7 Puzzle 3 at **168,480/128,000**, 3 unused turns,
  payout 18 (`1788778665646-bc60a386-9551-42cc-8d8e-0318907d576c`), cash
  237→255. Peek was used to choose 9; public Clue destination R1C6 and
  subsequent actual 9@R1C6 are evidenced by `1788778601904-9767c5d5-8c4e-4b90-a190-a0bda8121c08`
  and `1788778635783-55cf3d56-e7a2-4a61-b9ac-678cbd5c57d2`, then visible
  deductions completed the win. C-45 bought Peek for 3 and used four rerolls;
  the last Shop receipt is `1788778712696-176c79c1-aab4-4d7b-a12c-067abea2a3f8`
  with 238 coins expected from the visible sequence. No Extra Extra offer or
  Bookmark change was observed. Current honest status is **21/27 puzzles,
  zero full Books**; no unlock/return proof exists.

### Focused UI-21/22/23 gate

- The focused gate produced **34 unique checks across two runs**: 33 passed,
  with one raw JSON object-key-order assertion failure; the narrow rerun passed
  (`/tmp/numberclub-product-ui21-short-after-20260907.xcresult/log`, 1 pass,
  2.684s). The corrected assertion uses the existing sorted-key encoder; no
  product change was made. The Release build succeeded at
  `/tmp/numberclub-product-ui21-23-release-20260907.log`. C47's settled native
  Results evidence passes UI-21; C49's sampled clip passes UI-22 attribution
  readability. UI-23 guard tests pass without deliberate native double-tap proof.
  Current gameplay status later reached **27/27 puzzles, one full Book**.

### C-46 continuation

- C-46 won Level 8 easy at **189,540/128,000**, 6 unused turns, payout 21
  (`1788779081431-c6c21edf-8cde-4407-8d3b-a8ca6ed635d6`). The win showed
  241 coins including the Copper clear, then cash-out reached 262. Peek was
  bought for 3, leaving 259 (`1788779088813-565c036d-91e1-4796-93a6-e473e1025fb0`).
  Level 8 easy-but-hard remained partial at **34,200/192,000**, Turn 3/10,
  4 Tosses, hand 4,1 (`1788779129970-76aab9d6-8f2f-4779-95a9-ecc03d4f98d8`).
  A late placement was not confirmed. The AX win capture was mid-page-flip and
  included new “Your board as played” text, so UI-21 native visual status is
  inconclusive; UI-23 native evidence remains pending. Current honest status is
  **22/27 puzzles, zero full Books**; no unlock/return proof exists.

### C-47 continuation

- C-47 won Level 8 Puzzle 2 at **247,140/192,000**, 5 unused turns, payout 20
  (`1788779216353-c52c369f-8ff4-45df-9d80-54d438c6d640`), cash 259→279 with
  no purchases. The fully settled iPad Results screenshot showed the updated
  board preview, readable actual blanks, and footer; UI-21 native visual status
  passes. Garry Gray remained partial at **96,390/256,000**, Turn 5/10, no Toss,
  hand 9,9,1,2,5,5 (`1788779276405-f8a5db1d-fea8-4331-a4d5-f72af4e477fd`).
  Current honest status is **23/27 puzzles, zero full Books**; no unlock/return proof exists.

### C-48 continuation

- C-48 won Garry Gray at **317,925/256,000**, 4 unused turns, payout 19
  (`1788779440680-e6ccd55a-97c0-4cc5-bf9b-350a45e30b3f`), cash 279→298.
  One Peek selected 9@R1C2 (`1788779352234-07e47ce1-a420-4664-9916-fb27911cafcf`),
  then visible deductions chained to the win. Seven normal rerolls sought Extra
  Extra (costs 2+3+4+5+6+7+8=35); none was bought. Final Shop receipt
  `1788779487412-e5d773b8-43df-4253-9667-363790d1f085` showed 263 expected coins.
  Level 9 briefing identified final boss “The Budget Cut,” with all score
  multipliers halved (`1788779489452-c40f1953-eac0-4078-8e6e-71227f76c425`);
  Level 9 easy started at 0/256,000 Turn 1/10 (`1788779493197-a6055e50-d0b3-4b1b-8b09-7c131f753a5e`).
  Current honest status is **24/27 puzzles, zero full Books**; no unlock/return proof exists.

### C-49 continuation

- C-49 won Level 9 easy at **285,120/256,000**, 5 unused turns, payout 20
  (`1788779637327-3211d478-0b9c-40cc-b376-7a0b3c33dc34`), with 266 coins
  including the Copper bonus, then cash-out reached 286. Extra Extra was
  offered and bought for 7 after selling Letters to the Editor
  (`1788779639488-a4ccd645-bd7a-466b-8f51-c8c9e7ad10a3`). Level 9 Puzzle 2
  remained partial at **8,640/384,000**, Turn 2/10, 4 Tosses, hand 5,5
  (`1788779680616-cd8e15ad-4674-4d11-9ef8-2765721d850c`).
- UI-22 native attribution specifically passes in C49’s 12-second clip
  `/tmp/numberclub-score-ui22-live.mov` and reviewed contact sheet
  `/tmp/numberclub-score-ui22-live-contact.png`: sampled Sunday/Stop/Front
  Page/Rolling labels and turn points, Book bonus, Line complete, and Added to
  queue remained readable as single lines without overlap. This is not a
  blanket 60fps or device-performance claim. Current honest status is **25/27
  puzzles, zero full Books**; no unlock/return proof exists.
