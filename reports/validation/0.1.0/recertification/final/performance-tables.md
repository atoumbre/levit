
Generated run artifacts were removed during cleanup on 2026-11-24. Historical artifact paths refer to Git commit `bd1a095`.

### Profile workload latency

| Diagnostics | Workload | Reference ms | Before fixes ms | Candidate ms | vs reference | vs before |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Off | 10,000 observed writes | 0.192 | 0.196 | 0.262 | +36.3% | +33.9% |
| Off | 128 computed consumers × 100 writes | 3.119 | 3.057 | 3.085 | -1.1% | +0.9% |
| Off | 100 scope lifetimes | 0.250 | 0.354 | 0.342 | +36.9% | -3.3% |
| Off | 100 leaf tasks | 0.160 | 0.478 | 0.258 | +61.2% | -46.2% |
| Off | Virtualized 1,000-row list: frame wall time | 8.316 | 8.309 | 8.304 | -0.1% | -0.1% |
| On | 10,000 observed writes | 43.215 | 125.817 | 84.958 | +96.6% | -32.5% |
| On | 128 computed consumers × 100 writes | 58.940 | 168.541 | 112.275 | +90.5% | -33.4% |
| On | 100 scope lifetimes | 3.874 | 23.296 | 14.491 | +274.0% | -37.8% |
| On | 100 leaf tasks | 0.164 | 0.486 | 0.267 | +62.7% | -45.0% |
| On | Virtualized 1,000-row list: frame wall time | 8.284 | 8.310 | 8.319 | +0.4% | +0.1% |

### Release workload latency

| Diagnostics | Workload | Reference ms | Before fixes ms | Candidate ms | vs reference | vs before |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Off | 10,000 observed writes | 0.171 | 0.148 | 0.191 | +11.7% | +29.1% |
| Off | 128 computed consumers × 100 writes | 2.846 | 2.953 | 2.904 | +2.0% | -1.6% |
| Off | 100 scope lifetimes | 0.239 | 0.359 | 0.357 | +49.4% | -0.6% |
| Off | 100 leaf tasks | 0.157 | 0.479 | 0.256 | +63.0% | -46.7% |
| Off | Virtualized 1,000-row list: frame wall time | 8.329 | 8.323 | 8.328 | -0.0% | +0.1% |
| On | 10,000 observed writes | 44.010 | 121.671 | 82.815 | +88.2% | -31.9% |
| On | 128 computed consumers × 100 writes | 59.985 | 159.425 | 109.900 | +83.2% | -31.1% |
| On | 100 scope lifetimes | 3.860 | 22.958 | 14.630 | +279.0% | -36.3% |
| On | 100 leaf tasks | 0.157 | 0.476 | 0.266 | +70.1% | -44.1% |
| On | Virtualized 1,000-row list: frame wall time | 8.318 | 8.325 | 8.317 | -0.0% | -0.1% |

### Flutter engine timings

Pooled medians / nearest-rank p95, milliseconds; 360 matched frames per row.

| Mode | Diagnostics | Revision | Build median / p95 | Raster median / p95 |
| --- | --- | --- | ---: | ---: |
| profile | Off | reference | 1.704 / 3.023 | 0.394 / 0.545 |
| profile | Off | before | 1.681 / 2.650 | 0.387 / 0.576 |
| profile | Off | candidate | 1.882 / 2.436 | 0.412 / 0.589 |
| profile | On | reference | 1.982 / 2.378 | 0.420 / 0.580 |
| profile | On | before | 1.812 / 2.366 | 0.406 / 0.569 |
| profile | On | candidate | 1.860 / 2.425 | 0.429 / 0.515 |
| release | Off | reference | 1.739 / 2.379 | 0.371 / 0.529 |
| release | Off | before | 1.710 / 2.349 | 0.402 / 0.567 |
| release | Off | candidate | 1.659 / 2.299 | 0.407 / 0.544 |
| release | On | reference | 1.927 / 2.339 | 0.392 / 0.532 |
| release | On | before | 1.855 / 2.390 | 0.374 / 0.491 |
| release | On | candidate | 1.917 / 2.436 | 0.400 / 0.513 |
