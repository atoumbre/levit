# Collection redesign candidate — November 14, 2026

Candidate source manifest: `cebb44ff16d8189994c90fb1b0aeadb93dc7f7546e17189abeed1634aa33135a`. Dependency manifest for 23 active locks: `c532e4fc9cf2bcafde7976cfc989baa31d7de50dbe3962d87598e23896ccd6e5`. The [starting checkout](baseline.json) also archives two historical comparison locks. No package has been published.

| Gate | Result |
| --- | --- |
| Formatting | [Passed](format.log) |
| Clean local workspace, 22 packages | [Passed](snapshot-bootstrap.log) |
| Fatal-info analysis, native lint, Dart and Flutter suites | [Passed](ci.log) |
| Coverage, 11 packages | [Passed (7009/7009, 100.00%)](final-coverage.log) |
| Stress suite | [Passed](final-stress.log) |
| Benchmark harness | [Passed](benchmark-tests.log) |
| Browser builds and bundled inspector | [Passed](final-browser.log) |
| Packaged inspector startup and local asset delivery | [Passed](candidate-cli-consumer.json) |
| All 10 publication dry-runs, clean snapshot | [Passed](final-clean-publish-dry-run.log) |

The catalog favorite-only probe rebuilt one of six rows. The save indicator remained unchanged. The mounted route also exercised pagination, retained-data refresh, optimistic rollback and pending-load teardown. Diagnostic tests checked that a raw key was absent from wire events, history and snapshots while the producer retained its owner.

## Matched workloads

The [input checks](comparison-inputs.json) verify identical dashboard Dart sources and lockfile against the pre-redesign snapshot. The 539f130 reference uses the same release workload entrypoint, with different local Levit packages and matched external dependencies. Profile and release run separately, diagnostics off and on in separate processes. Raw timings include cleanup when the original workload does.

## Collection workloads

128 observed addresses, 256 operations per sample, 2 warmups and 9 measured samples per process. Reverse ordering on the second pair. A list shift is an insertion and removal; bulk writes two keys. Times cover the operations and synchronous observation; setup and final teardown are excluded.

| Workload | Before p50 (µs) | Candidate p50 (µs) | Change | Computed runs before → after |
| --- | ---: | ---: | ---: | ---: |
| sparseMap | 3,228 | 103 | -96.8% | 32,768 → 256 |
| sparseIndex | 2,732 | 81 | -97.0% | 32,768 → 256 |
| shift | 5,779 | 10,355 | +79.2% | 65,536 → 49,152 |
| bulk | 3,147 | 2,157 | -31.5% | 32,768 → 512 |
| churn | 192 | 656 | +240.5% | 256 → 256 |

[Timed workload](../../../../packages/core/levit_reactive/benchmark/collection_addresses.dart). The regression suite separately checks that untracked reads allocate zero channels and that all observed channels retire when the last consumer detaches.

**Native performance sign-off remains open.** The first native reference case
timed out after 300 seconds with the macOS session locked. The driver stopped
without a complete frame report (0 of 24).
There is no fresh native delta against either checkout yet. See the
[session check](native-session-status.json), [native run log](native-run.log)
and [reproduction instructions](REPRODUCE.md). The previous release certificate
does not cover this source.

Both AOT pairs show the same directions. Sparse writes now cause 256 instead
of 32,768 computed evaluations. The shift changes three quarters of observed
positions and still pays for positional invalidation; the churn workload
creates and retires a channel per short-lived subscription. These are plausible
costs, not CPU-profile attribution. Neither the sparse improvement nor the
slower churn should be extrapolated to whole applications. Performance sign-off
also requires accounting for these repeatable slower paths.

The [archive manifest](candidate-archive.json) identifies the verified,
unpublished source snapshot. No publishing command was run without `--dry-run`.
