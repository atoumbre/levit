# Benchmark Results
Date: 2026-11-26 07:36:45.448586

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
| Vanilla | 502 | 678 | 529.7 | 439-822 | 75.8 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Levit | 566 | 698 | 587.8 | 523-864 | 61.7 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| GetX | 802 | 892 | 810.2 | 750-962 | 42.4 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 3685 | 4471 | 3810.8 | 3425-5335 | 329.9 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| BLoC | 82450 | 88600 | 83378.8 | 77098-132384 | 6287.3 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Diamond Graph (Observed Updates)
Measurement: Completed logic work (wall time)  
Methodology: 2 (not comparable with earlier app results)
Classification: Approximate  
Note: Consumes the final diamond result after every root write. Intermediate notification counts can differ.
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| Vanilla | 51 | 80 | 58.2 | 49-243 | 27.1 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Levit | 52 | 106 | 63.6 | 48-228 | 25.8 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 1539 | 1686 | 1538.3 | 1412-1810 | 85.4 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| RxDart | 1670 | 1810 | 1696.0 | 1618-2325 | 85.8 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| GetX | 16646 | 28597 | 18427.5 | 14755-47097 | 4700.6 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Fan Out Update
Measurement: Completed logic work (wall time)  
Methodology: 2 (not comparable with earlier app results)
Classification: Comparative
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| Vanilla | 7 | 14 | 8.5 | 6-37 | 4.6 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| GetX | 14 | 21 | 15.2 | 11-39 | 3.3 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Levit | 39 | 88 | 46.4 | 30-256 | 28.6 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 125 | 180 | 136.3 | 108-500 | 44.4 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| RxDart | 480 | 572 | 492.2 | 464-846 | 48.2 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Fan In Update
Measurement: Completed logic work (wall time)  
Methodology: 2 (not comparable with earlier app results)
Classification: Comparative
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| Vanilla | 13 | 25 | 15.4 | 10-72 | 9.3 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| GetX | 13 | 29 | 16.9 | 10-124 | 14.6 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Levit | 15 | 27 | 16.8 | 13-43 | 5.5 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| RxDart | 45 | 92 | 51.3 | 34-147 | 21.0 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 400 | 553 | 424.3 | 357-670 | 64.6 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Async Computed
Measurement: Completed logic work (wall time)  
Methodology: 2 (not comparable with earlier app results)
Classification: Approximate  
Note: Measures sequential async recomputation using each framework's closest async primitive.
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| Vanilla | 743 | 1126 | 782.2 | 606-1405 | 158.8 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| GetX | 916 | 1201 | 968.2 | 787-2218 | 179.1 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| RxDart | 1368 | 1783 | 1415.4 | 1128-1869 | 187.2 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 1491 | 2110 | 1554.5 | 1138-2639 | 303.4 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Levit | 1829 | 2431 | 1870.6 | 1422-2697 | 310.8 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Batch vs Un-batched
Measurement: Completed logic work (wall time)  
Methodology: 2 (not comparable with earlier app results)
Classification: Feature Demo  
Note: Levit uses a native batching primitive; others measure un-batched closest equivalents.
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| ValueNotifier (substitute) | 18 | 40 | 21.0 | 16-61 | 8.7 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| GetX | 21 | 35 | 24.2 | 20-95 | 11.4 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Levit | 41 | 92 | 47.0 | 22-180 | 27.0 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 86 | 188 | 113.0 | 75-704 | 82.4 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Vanilla | 136 | 228 | 150.0 | 129-308 | 32.9 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Warm Root DI Lookup
Measurement: Completed logic work (wall time)  
Methodology: 2 (not comparable with earlier app results)
Classification: Feature Demo  
Note: DI containers are not first-class primitives in every framework.
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| Custom map (substitute) | 6 | 17 | 8.4 | 5-97 | 10.0 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Vanilla | 6 | 11 | 7.2 | 5-29 | 3.6 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Levit | 19 | 46 | 22.7 | 13-220 | 22.5 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 22 | 43 | 28.9 | 21-240 | 26.7 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| GetX | 119 | 184 | 130.0 | 115-269 | 25.5 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Computed Chain (Deep Propagation)
Measurement: Completed logic work (wall time)  
Methodology: 2 (not comparable with earlier app results)
Classification: Approximate  
Note: An observed leaf consumes every root update through the closest computed/stream primitive.
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| Levit | 86 | 144 | 95.8 | 79-253 | 24.6 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Vanilla | 212 | 331 | 229.1 | 194-495 | 51.5 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| GetX | 358 | 450 | 372.3 | 342-458 | 32.0 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| BLoC | 32807 | 33927 | 32666.7 | 30644-34552 | 827.2 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 108689 | 113276 | 108611.1 | 99112-185376 | 8523.1 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Virtualized List: Visible Row Update (UI)
Measurement: Widget-test pump wall time (not device rendering)  
Methodology: 2 (not comparable with earlier app results)
Classification: Comparative
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| GetX | 1042 | 1528 | 1089.2 | 733-2163 | 248.8 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Vanilla | 1089 | 1472 | 1128.2 | 763-3609 | 340.7 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Levit | 1279 | 1692 | 1269.5 | 771-2569 | 317.9 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 1684 | 2612 | 1819.7 | 988-7020 | 704.1 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| BLoC | 2499 | 3647 | 2594.1 | 1516-5073 | 676.6 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Nested Leaf Rebuild (UI)
Measurement: Widget-test pump wall time (not device rendering)  
Methodology: 2 (not comparable with earlier app results)
Classification: Comparative
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| GetX | 767 | 1115 | 802.6 | 518-1663 | 181.3 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Levit | 777 | 1010 | 784.7 | 523-1232 | 134.3 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Vanilla | 815 | 1136 | 829.3 | 512-1208 | 163.4 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| BLoC | 821 | 1403 | 907.3 | 551-2731 | 365.3 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 1045 | 2116 | 1133.1 | 577-4371 | 492.5 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Dynamic Grid Churn (UI)
Measurement: Widget-test pump wall time (not device rendering)  
Methodology: 2 (not comparable with earlier app results)
Classification: Comparative
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| GetX | 7820 | 17793 | 9535.0 | 6026-70985 | 7772.5 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 8438 | 10858 | 8847.3 | 7126-20983 | 1972.9 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| BLoC | 9036 | 13098 | 9367.0 | 6995-21298 | 2399.5 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Levit | 9142 | 13462 | 9649.6 | 7014-36065 | 3602.7 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Vanilla | 10460 | 18269 | 11592.0 | 7604-44294 | 5194.6 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

## Progress Bar State Update (UI)
Measurement: Widget-test pump wall time (not device rendering)  
Methodology: 2 (not comparable with earlier app results)
Classification: Comparative
| Implementation | Median (µs) | p95 (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|---|
| Vanilla | 161 | 341 | 193.6 | 135-796 | 88.8 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Riverpod | 173 | 428 | 233.3 | 142-2123 | 219.0 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| GetX | 244 | 472 | 288.9 | 167-1586 | 172.3 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| BLoC | 266 | 476 | 304.1 | 175-1988 | 197.7 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |
| Levit | 293 | 563 | 365.6 | 199-2773 | 308.1 | 100 | OK — The benchmark completed successfully, its results passed verification, and its resources were cleaned up successfully. |

