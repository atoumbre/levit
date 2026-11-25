
Generated run artifacts were removed during cleanup on 2026-11-24. Historical artifact paths refer to Git commit `bd1a095`.

### Profile workload latency

| Diagnostics | Workload | Reference ms | Candidate ms | Change |
| --- | --- | ---: | ---: | ---: |
| Off | 10,000 observed writes | 2.294 | 0.176 | -92.3% |
| Off | 128 computed consumers × 100 writes | 6.647 | 3.751 | -43.6% |
| Off | 100 scope lifetimes | 0.310 | 0.357 | +15.2% |
| Off | 100 leaf tasks | 0.164 | 0.499 | +204.0% |
| Off | Virtualized 1,000-row list: frame wall time | 8.310 | 8.325 | +0.2% |
| On | 10,000 observed writes | 46.088 | 133.476 | +189.6% |
| On | 128 computed consumers × 100 writes | 62.527 | 177.528 | +183.9% |
| On | 100 scope lifetimes | 4.010 | 23.837 | +494.5% |
| On | 100 leaf tasks | 0.164 | 0.555 | +239.1% |
| On | Virtualized 1,000-row list: frame wall time | 8.305 | 8.320 | +0.2% |

### Release workload latency

| Diagnostics | Workload | Reference ms | Candidate ms | Change |
| --- | --- | ---: | ---: | ---: |
| Off | 10,000 observed writes | 2.333 | 0.259 | -88.9% |
| Off | 128 computed consumers × 100 writes | 6.170 | 3.278 | -46.9% |
| Off | 100 scope lifetimes | 0.297 | 0.352 | +18.4% |
| Off | 100 leaf tasks | 0.162 | 0.483 | +198.9% |
| Off | Virtualized 1,000-row list: frame wall time | 8.320 | 8.324 | +0.0% |
| On | 10,000 observed writes | 46.692 | 130.967 | +180.5% |
| On | 128 computed consumers × 100 writes | 62.428 | 171.599 | +174.9% |
| On | 100 scope lifetimes | 4.180 | 24.146 | +477.7% |
| On | 100 leaf tasks | 0.159 | 0.493 | +209.4% |
| On | Virtualized 1,000-row list: frame wall time | 8.287 | 8.295 | +0.1% |

### Flutter engine timings

Pooled medians / nearest-rank p95, milliseconds; 360 matched frames per row.

| Mode | Diagnostics | Revision | Build median / p95 | Raster median / p95 |
| --- | --- | --- | ---: | ---: |
| profile | Off | reference | 1.708 / 2.468 | 0.442 / 0.617 |
| profile | Off | candidate | 1.565 / 2.386 | 0.406 / 0.564 |
| profile | On | reference | 1.666 / 2.345 | 0.429 / 0.617 |
| profile | On | candidate | 1.559 / 2.166 | 0.405 / 0.530 |
| release | Off | reference | 1.569 / 2.252 | 0.413 / 0.594 |
| release | Off | candidate | 1.677 / 2.526 | 0.413 / 0.592 |
| release | On | reference | 1.601 / 2.289 | 0.398 / 0.566 |
| release | On | candidate | 1.651 / 2.334 | 0.410 / 0.550 |
