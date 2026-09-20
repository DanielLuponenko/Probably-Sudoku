# Same-process navigation memory measurements

19 September 2026. Isolated iPhone 17 Pro simulator D04; app PID 9412, baseline graphics build 2, nonpersisting Shop fixture. Each cycle closed the Redraw offer, opened and closed Settings, and reopened the same offer. The native reviewer performed 30 cycles with fresh accessibility queries. No purchases, coin changes, crashes, or relaunches occurred.

Each capture was taken at the same settled Redraw detail, using app-only `vmmap -summary` and `leaks --noContent`. Memory graphs exclude allocation content descriptions.

| Settled point | Physical footprint | Allocated heap | Leak scan |
| --- | ---: | ---: | --- |
| Before cycles | 116.0 MB | 18,448 KB | 0 leaks, 0 bytes |
| After 15 cycles | 129.9 MB | 20,090 KB | 0 leaks, 0 bytes |
| After 30 cycles | 130.9 MB | 20,098 KB | 0 leaks, 0 bytes |

Peak physical footprint remained 218.9 MB at all three points. The second batch added only 8 KB of allocated heap and about 1 MB of resident footprint, consistent with bounded warm-up rather than per-cycle accumulation. This is evidence for these exercised navigation paths, not a claim that every possible leak has been ruled out or that Simulator memory predicts a physical iPhone exactly.

Logs and graphs:

- `/tmp/nc-native-memory-before-{analysis,vmmap}.log`, `/tmp/nc-native-memory-before.memgraph`
- `/tmp/nc-native-memory-after15-{analysis,vmmap}.log`, `/tmp/nc-native-memory-after15.memgraph`
- `/tmp/nc-native-memory-after30-{analysis,vmmap}.log`, `/tmp/nc-native-memory-after30.memgraph`

Separate app-hosted weak-reference tests verify release of departed GameModels, page-turn renderers, capture anchors, paper presenters, SceneKit stands, and completion snapshots. Those tests detected and then verified the fix for three bounded animation-task retentions; the native leak scans alone could not prove that fix.
