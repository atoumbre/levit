# Native AOT Benchmark Results
Generated: 2026-11-26T16:20:38.219537Z

> Measured using `benchmarks/lib/release_performance.dart` in native `release` AOT mode across 3 rounds per diagnostic state (separate processes). See [`benchmarks/README.md`](../benchmarks/README.md#native-release-comparison) for methodology details.

## Environment
| Key | Value |
|---|---|
| Build Mode | `release` (native macOS AOT) |
| Dart Runtime | `3.12.2 (stable) (Tue Jun 9 01:11:39 2026 -0700) on "macos_arm64"` |
| Operating System | `Version 26.6.2 (Build 25G83)` |
| CPU Threads | `8` |
| Display Refresh Rate (Hz) | `120.0` |
| Activity Guard (`LEVIT_PERFORMANCE_RUN=1`) | `true` |

## Workload Summary (Diagnostics Off vs. On)
| Workload | Diagnostics | Median (µs) | p95 (µs) | Mean (µs) | Min–Max (µs) | Body Median (µs) | Samples | Peak RSS (MB) |
|---|---|---:|---:|---:|---|---:|---:|---:|
| `notify_10000` | off | 144 | 194 | 151.7 | 140–284 | 134 | 90 | 109.0 |
| `notify_10000` | on | 42853 | 45083 | 42569.1 | 38554–47897 | 42809 | 90 | 223.7 |
| `fanout_128_x_100` | off | 1496 | 1637 | 1518.6 | 1443–1704 | 1478 | 90 | 108.1 |
| `fanout_128_x_100` | on | 57906 | 60889 | 58157.2 | 55782–64378 | 57865 | 90 | 123.8 |
| `scope_lifetime_100` | off | 270 | 379 | 289.1 | 256–448 | 258 | 90 | 108.1 |
| `scope_lifetime_100` | on | 4634 | 6885 | 4959.9 | 4121–7717 | 4596 | 90 | 127.1 |
| `tasks_100` | off | 165 | 288 | 182.9 | 156–337 | 154 | 90 | 108.1 |
| `tasks_100` | on | 156 | 195 | 161.9 | 151–285 | 152 | 90 | 124.7 |
| `list_1000_frame` | off | 8311 | 8755 | 8350.6 | 7744–10845 | 8278 | 180 | 106.7 |
| `list_1000_frame` | on | 8320 | 8620 | 8325.7 | 6319–9975 | 8286 | 180 | 120.8 |

## Mounted 1,000-Row List Frame Timings (`list_1000_frame`)
| Diagnostics | Build p50 (µs) | Build p95 (µs) | Raster p50 (µs) | Raster p95 (µs) | Frames |
|---|---:|---:|---:|---:|---:|
| off | 1393 | 1795 | 408 | 480 | 180 |
| on | 1485 | 1824 | 392 | 476 | 180 |
