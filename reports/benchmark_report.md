# Benchmark Results
Date: 2026-11-26 11:17:37.335117

## Environment
| Key | Value |
|---|---|
| Source Revision | unrecorded |
| Display Refresh Rate (Hz) | unrecorded |
| Execution Context | flutter_test_report |
| Build Mode | debug |
| Benchmark Profile | test |
| Iterations | 100 |
| Warmup Iterations | 50 |
| Framework Order Rotation | Enabled |
| Frameworks | Vanilla, Levit, GetX, BLoC, Riverpod |
| Benchmarks | Rapid State Mutation, Diamond Graph (Observed Updates), Fan Out Update, Fan In Update, Async Computed, Batch vs Un-batched, Warm Root DI Lookup, Computed Chain (Deep Propagation), Virtualized List: Visible Row Update (UI), Nested Leaf Rebuild (UI), Dynamic Grid Churn (UI), Progress Bar State Update (UI) |
| Operating System | macos |
| OS Version | Version 26.6.2 (Build 25G83) |
| Dart Version | 3.12.2 |
| CPU Threads | 8 |
| Locale | en_US |

## Rapid State Mutation
Measurement: Completed logic work (wall time)  
Methodology: 2 (not comparable with earlier app results)
Classification: Comparative
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| Vanilla | 520 | 765 | 560.5 | 436-1395 | 134.7 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Levit | 554 | 716 | 578.5 | 514-873 | 66.3 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| GetX | 803 | 910 | 816.1 | 737-1312 | 73.8 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 3655 | 3946 | 3687.1 | 3459-4262 | 149.0 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| BLoC | 81205 | 85560 | 81146.2 | 76739-87508 | 3263.9 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Diamond Graph (Observed Updates)
Measurement: Completed logic work (wall time)  
Methodology: 2 (not comparable with earlier app results)
Classification: Approximate  
Note: Consumes the final diamond result after every root write. Intermediate notification counts can differ.
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| Levit | 51 | 78 | 59.6 | 49-197 | 20.9 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Vanilla | 53 | 88 | 61.2 | 51-254 | 28.5 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| RxDart | 1721 | 1842 | 1733.7 | 1602-1953 | 68.8 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 1809 | 3807 | 2444.4 | 1464-15382 | 2237.3 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| GetX | 15847 | 17423 | 18848.0 | 15153-128397 | 16764.0 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Fan Out Update
Measurement: Completed logic work (wall time)  
Methodology: 2 (not comparable with earlier app results)
Classification: Comparative
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| Vanilla | 7 | 14 | 8.7 | 6-60 | 6.6 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| GetX | 15 | 28 | 17.3 | 12-54 | 6.9 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Levit | 39 | 133 | 51.5 | 30-210 | 33.9 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 146 | 257 | 160.3 | 110-540 | 60.4 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| RxDart | 511 | 648 | 531.7 | 469-897 | 65.5 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Fan In Update
Measurement: Completed logic work (wall time)  
Methodology: 2 (not comparable with earlier app results)
Classification: Comparative
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| GetX | 13 | 34 | 17.3 | 10-82 | 10.1 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Vanilla | 14 | 35 | 16.9 | 10-49 | 7.7 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Levit | 16 | 34 | 17.3 | 12-42 | 6.7 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| RxDart | 46 | 90 | 55.0 | 34-209 | 27.3 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 418 | 583 | 437.9 | 355-647 | 63.6 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Async Computed
Measurement: Completed logic work (wall time)  
Methodology: 2 (not comparable with earlier app results)
Classification: Approximate  
Note: Measures sequential async recomputation using each framework's closest async primitive.
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| Vanilla | 725 | 1143 | 793.9 | 578-2043 | 241.0 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| GetX | 879 | 1176 | 936.0 | 764-1495 | 143.3 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Levit | 1149 | 1623 | 1208.5 | 953-1780 | 209.0 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| RxDart | 1367 | 1840 | 1420.5 | 1128-2634 | 245.8 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 1467 | 2332 | 1540.3 | 1098-3263 | 372.0 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Batch vs Un-batched
Measurement: Completed logic work (wall time)  
Methodology: 2 (not comparable with earlier app results)
Classification: Feature Demo  
Note: Levit uses a native batching primitive; others measure un-batched closest equivalents.
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| ValueNotifier (substitute) | 17 | 26 | 19.1 | 16-76 | 7.0 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| GetX | 21 | 39 | 24.8 | 19-81 | 10.4 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Levit | 40 | 134 | 52.6 | 20-304 | 42.3 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 79 | 162 | 98.3 | 72-671 | 68.5 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Vanilla | 139 | 203 | 150.8 | 128-320 | 28.2 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Warm Root DI Lookup
Measurement: Completed logic work (wall time)  
Methodology: 2 (not comparable with earlier app results)
Classification: Feature Demo  
Note: DI containers are not first-class primitives in every framework.
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| Custom map (substitute) | 7 | 16 | 8.4 | 6-37 | 5.6 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Vanilla | 7 | 12 | 7.7 | 6-37 | 4.2 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Levit | 20 | 76 | 26.7 | 14-230 | 28.2 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 22 | 41 | 26.7 | 20-204 | 20.2 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| GetX | 120 | 182 | 132.3 | 113-276 | 26.1 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Computed Chain (Deep Propagation)
Measurement: Completed logic work (wall time)  
Methodology: 2 (not comparable with earlier app results)
Classification: Approximate  
Note: An observed leaf consumes every root update through the closest computed/stream primitive.
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| Levit | 87 | 142 | 95.5 | 80-244 | 23.5 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Vanilla | 215 | 348 | 233.2 | 197-469 | 47.4 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| GetX | 363 | 450 | 378.0 | 332-691 | 50.9 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| BLoC | 32804 | 36093 | 33779.3 | 32232-91260 | 6005.5 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 103556 | 104652 | 104225.4 | 102148-162194 | 6008.6 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Virtualized List: Visible Row Update (UI)
Measurement: Widget-test pump wall time (not device rendering)  
Methodology: 2 (not comparable with earlier app results)
Classification: Comparative
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| GetX | 1306 | 1833 | 1334.2 | 822-2196 | 270.8 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Levit | 1408 | 2282 | 1497.8 | 786-2667 | 396.8 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Vanilla | 1411 | 1936 | 1421.5 | 785-2230 | 341.2 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 1778 | 2935 | 1854.4 | 986-3694 | 525.6 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| BLoC | 2400 | 3944 | 2573.3 | 1648-5114 | 663.6 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Nested Leaf Rebuild (UI)
Measurement: Widget-test pump wall time (not device rendering)  
Methodology: 2 (not comparable with earlier app results)
Classification: Comparative
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| Levit | 730 | 1898 | 927.2 | 514-6276 | 661.9 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| BLoC | 814 | 1237 | 871.6 | 574-1461 | 190.5 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Vanilla | 816 | 1131 | 819.2 | 508-1496 | 192.4 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| GetX | 850 | 1245 | 886.0 | 524-1655 | 199.5 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 1090 | 2226 | 1239.5 | 593-4808 | 585.8 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Dynamic Grid Churn (UI)
Measurement: Widget-test pump wall time (not device rendering)  
Methodology: 2 (not comparable with earlier app results)
Classification: Comparative
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| GetX | 8632 | 10708 | 9044.4 | 7181-20760 | 2045.6 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Levit | 8726 | 13561 | 9483.2 | 7208-22837 | 2636.0 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| BLoC | 8897 | 11213 | 9161.1 | 7381-22097 | 2188.8 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 8945 | 12581 | 9631.5 | 7441-51475 | 4764.5 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Vanilla | 10635 | 14258 | 10990.7 | 7818-26705 | 2536.0 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Progress Bar State Update (UI)
Measurement: Widget-test pump wall time (not device rendering)  
Methodology: 2 (not comparable with earlier app results)
Classification: Comparative
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| Vanilla | 160 | 310 | 193.5 | 140-897 | 100.2 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 179 | 435 | 228.8 | 151-884 | 127.7 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| GetX | 240 | 572 | 297.2 | 172-1658 | 197.3 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| BLoC | 256 | 545 | 313.0 | 178-1177 | 165.3 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Levit | 304 | 584 | 364.9 | 212-2359 | 264.2 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

