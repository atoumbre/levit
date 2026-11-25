# 0.1.0 redesign: replace families

A feature owns its replaceable producers. Collections describe where state
changed; an individual resource controls replacement; the Dart kit supplies
loading, retries, freshness and retention. No async list or public keyed-resource
manager is part of this design.

| Need | Public API | Lifetime |
| --- | --- | --- |
| Observe one map key or list position | `LxMap.entry`, `LxList.entry` in reactive core | Views borrow the collection; neither view nor collection owns stored objects. |
| Reconnect an existing stream or domain producer | `LxResource<T,R>` in reactive core | The feature owns the resource; the resource exclusively owns its producer. |
| Load by key | `LevitAsyncMap<K,T>` in the Dart kit | The feature owns the map; the map owns retained resources. A supplied engine is borrowed. |
| Order async entities | `LxList<ID>` and `LevitAsyncMap<ID,T>` | Reordering IDs preserves entity requests and freshness. |

1. **Freeze the inputs.** Archive the dirty starting checkout, lockfiles and
   SDK identities. Keep the release reference `539f130` separate. Carry forward
   the 33 passing review tests and the four defect probes.
2. **Observe map addresses.** Separate key value, membership, count, emptiness,
   ordered keys and aggregate reads. Borrowed entries survive removal and
   reinsertion; `exists` disambiguates null. Allocate channels only on observed
   reads; preserve lookup semantics when the backing map has custom equality.
   Route bulk, cast, replacement, binding and explicit refresh through publication.
3. **Observe list positions.** A shifted position changes even if its new value
   is an equal duplicate. Preserve ordinary range errors, backed views and
   cast writes. Cover partial failures, batching, capture after await and
   activation after a previously captured channel has retired.
4. **Own one producer.** Reserve refresh before notification. Reject a self-join,
   detach, cancel and drain the old generation, then construct, attach and read
   the replacement. A failed first read rejects refresh and closes the failed
   producer. Preserve prior data and subscriber identity; do not start unused
   resources during close. Exclude the returned producer from ambient controller
   cleanup capture without excluding independent sibling state.
5. **Compose keyed loading.** One stable, borrowing entry per retained lifetime.
   Indexing starts missing loads; fetch joins pending work or reuses fresh data.
   Refresh joins a running request or waits for the new load result. Active
   observers and admitted operations pin entries; use a separate inactive LRU.
   Default freshness and grace are each 30 seconds; the inactive budget is 128.
   Evicted views stay closed. Drain current and retiring producers at close.
6. **Migrate consumers and remove families.** Port the catalog, Flutter builders,
   adapters, lints, browser entrypoints and docs. Include core-only stream
   refresh and ordered async examples. Remove the legacy APIs without aliases.
7. **Validate and compare.** Run release gates on coordinated sources. Measure
   unchanged native workloads against both references, in separate diagnostic
   modes. Measure sparse edits, shifts, bulk writes, churn and retained channels.
   Do not infer framework-wide speedups from reduced catalog rebuilds. Keep
   performance sign-off open for unexplained repeatable regressions.

[Progress and acceptance evidence](release_0.1.0_progress.md) ·
[Candidate, inputs and measurements](validation/0.1.0/collection-redesign/CANDIDATE.md) ·
[Migration examples](../docs/MIGRATION_0.1.0.md).
