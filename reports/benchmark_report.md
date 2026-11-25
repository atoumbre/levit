# Benchmark Results
Date: 2026-11-24 20:49:12.647317

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
| Vanilla | 511 | 670 | 536.7 | 441-1584 | 129.2 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Levit | 624 | 1175 | 905.0 | 522-20653 | 1997.1 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| GetX | 862 | 1146 | 903.9 | 774-2605 | 200.9 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 3949 | 5341 | 4130.8 | 3628-7328 | 545.2 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| BLoC | 86973 | 118008 | 91441.5 | 77244-255884 | 21817.0 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Diamond Graph (Observed Updates)
Measurement: Completed logic work (wall time)  
Methodology: 2 (not comparable with earlier app results)
Classification: Approximate  
Note: Consumes the final diamond result after every root write. Intermediate notification counts can differ.
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| Levit | 54 | 144 | 72.9 | 48-615 | 68.0 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Vanilla | 55 | 112 | 64.5 | 51-249 | 29.8 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 1704 | 2269 | 1767.2 | 1475-3094 | 249.1 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| RxDart | 1868 | 3048 | 2075.3 | 1622-6994 | 677.2 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| GetX | 18595 | 23844 | 19254.2 | 16856-27306 | 1953.9 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Fan Out Update
Measurement: Completed logic work (wall time)  
Methodology: 2 (not comparable with earlier app results)
Classification: Comparative
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| Vanilla | 7 | 18 | 8.8 | 5-50 | 6.4 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| GetX | 15 | 32 | 18.4 | 12-63 | 7.8 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Levit | 32 | 104 | 41.3 | 20-256 | 37.1 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 132 | 328 | 165.5 | 110-478 | 71.9 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| RxDart | 559 | 827 | 606.4 | 465-2805 | 242.2 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Fan In Update
Measurement: Completed logic work (wall time)  
Methodology: 2 (not comparable with earlier app results)
Classification: Comparative
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| Vanilla | 13 | 47 | 18.9 | 10-206 | 22.7 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| GetX | 13 | 39 | 17.7 | 10-74 | 11.0 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Levit | 18 | 45 | 21.4 | 13-115 | 13.6 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| RxDart | 43 | 89 | 49.5 | 34-213 | 21.8 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 448 | 641 | 473.7 | 367-925 | 90.4 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Async Computed
Measurement: Completed logic work (wall time)  
Methodology: 2 (not comparable with earlier app results)
Classification: Approximate  
Note: Measures sequential async recomputation using each framework's closest async primitive.
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| Vanilla | 816 | 1657 | 935.6 | 629-4166 | 449.6 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| GetX | 994 | 1860 | 1090.1 | 726-3077 | 350.6 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| RxDart | 1472 | 2733 | 1670.6 | 1163-7478 | 744.1 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 1555 | 2738 | 1707.0 | 1178-4400 | 495.3 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Levit | 2183 | 5542 | 3976.8 | 1379-123600 | 12255.8 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Batch vs Un-batched
Measurement: Completed logic work (wall time)  
Methodology: 2 (not comparable with earlier app results)
Classification: Feature Demo  
Note: Levit uses a native batching primitive; others measure un-batched closest equivalents.
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| ValueNotifier (substitute) | 17 | 30 | 21.6 | 17-209 | 20.1 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| GetX | 21 | 53 | 26.2 | 19-78 | 10.8 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Levit | 39 | 87 | 44.3 | 21-243 | 31.5 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 82 | 160 | 100.0 | 75-641 | 62.6 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Vanilla | 183 | 242 | 196.2 | 149-296 | 26.3 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Warm Root DI Lookup
Measurement: Completed logic work (wall time)  
Methodology: 2 (not comparable with earlier app results)
Classification: Feature Demo  
Note: DI containers are not first-class primitives in every framework.
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| Custom map (substitute) | 6 | 15 | 7.8 | 5-32 | 4.4 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Vanilla | 6 | 13 | 8.4 | 6-101 | 10.6 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 23 | 60 | 30.8 | 21-235 | 26.8 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Levit | 48 | 81 | 53.7 | 43-107 | 13.5 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| GetX | 126 | 200 | 137.8 | 116-284 | 30.0 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Computed Chain (Deep Propagation)
Measurement: Completed logic work (wall time)  
Methodology: 2 (not comparable with earlier app results)
Classification: Approximate  
Note: An observed leaf consumes every root update through the closest computed/stream primitive.
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| Levit | 79 | 155 | 91.6 | 76-333 | 32.2 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Vanilla | 217 | 385 | 249.8 | 200-916 | 90.6 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| GetX | 372 | 490 | 391.2 | 343-983 | 80.6 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| BLoC | 33475 | 36024 | 34115.8 | 31578-76198 | 4423.1 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 103286 | 109031 | 104858.3 | 98059-212296 | 11370.9 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Virtualized List: Visible Row Update (UI)
Measurement: Widget-test pump wall time (not device rendering)  
Methodology: 2 (not comparable with earlier app results)
Classification: Comparative
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| GetX | 1173 | 1670 | 1219.0 | 748-3142 | 336.0 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Levit | 1376 | 2213 | 1421.8 | 891-3733 | 432.2 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Vanilla | 1434 | 1926 | 1433.0 | 829-2227 | 305.2 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 1691 | 2939 | 1833.2 | 952-4702 | 596.0 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| BLoC | 2709 | 5621 | 3121.4 | 1613-9569 | 1396.5 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Nested Leaf Rebuild (UI)
Measurement: Widget-test pump wall time (not device rendering)  
Methodology: 2 (not comparable with earlier app results)
Classification: Comparative
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| Levit | 741 | 1109 | 770.7 | 542-1486 | 182.9 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| BLoC | 773 | 1260 | 832.0 | 559-1526 | 226.1 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| GetX | 786 | 1337 | 841.4 | 532-2256 | 274.2 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Vanilla | 831 | 1344 | 903.3 | 543-3141 | 349.9 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 995 | 1912 | 1132.5 | 642-3993 | 533.4 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Dynamic Grid Churn (UI)
Measurement: Widget-test pump wall time (not device rendering)  
Methodology: 2 (not comparable with earlier app results)
Classification: Comparative
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| Riverpod | 8824 | 11835 | 9213.7 | 6498-21020 | 2121.5 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| GetX | 8907 | 13510 | 9331.3 | 6988-23168 | 2379.9 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| BLoC | 9288 | 13511 | 9547.3 | 6832-20410 | 2363.2 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Levit | 10038 | 16317 | 12195.6 | 7547-152372 | 14493.6 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Vanilla | 10648 | 13692 | 11125.2 | 8006-24037 | 2500.4 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Progress Bar State Update (UI)
Measurement: Widget-test pump wall time (not device rendering)  
Methodology: 2 (not comparable with earlier app results)
Classification: Comparative
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| Riverpod | 175 | 479 | 247.6 | 146-1519 | 180.5 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Vanilla | 176 | 356 | 215.5 | 138-718 | 95.7 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| GetX | 219 | 533 | 274.6 | 167-1456 | 163.1 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| BLoC | 239 | 629 | 309.1 | 177-1082 | 164.9 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Levit | 307 | 738 | 381.8 | 208-1494 | 220.2 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

