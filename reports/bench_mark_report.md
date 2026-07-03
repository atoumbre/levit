# Benchmark Results
Date: 2026-06-26 13:55:02.361182

## Environment
| Key | Value |
|---|---|
| Execution Context | flutter_test_report |
| Build Mode | debug |
| Benchmark Profile | test |
| Iterations | 100 |
| Warmup Iterations | 50 |
| Framework Order Rotation | Enabled |
| Frameworks | Vanilla, Levit, GetX, BLoC, Riverpod |
| Benchmarks | Rapid State Mutation, Complex Graph (Diamond), Fan Out Update, Fan In Update, Async Computed, Batch vs Un-batched, Scoped DI Lookup, Computed Chain (Deep Propagation), Large List Update (UI), Deep Tree Propagation (UI), Dynamic Grid Churn (UI), Animated State - 60fps (UI) |
| Operating System | macos |
| OS Version | Version 26.5.1 (Build 25F80) |
| Dart Version | 3.11.1 |
| CPU Threads | 8 |
| Locale | en_US |

## Rapid State Mutation
Classification: Comparative
| Framework | Median (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|
| Levit | 436 | 458.9 | 410-794 | 60.2 | 100 | OK |
| BLoC | 511 | 586.7 | 438-2656 | 283.5 | 100 | OK |
| Vanilla | 520 | 558.5 | 443-1114 | 111.9 | 100 | OK |
| GetX | 637 | 649.7 | 606-1027 | 53.7 | 100 | OK |
| Riverpod | 3836 | 4004.8 | 3473-5883 | 472.8 | 100 | OK |

## Complex Graph (Diamond)
Classification: Approximate  
Note: Uses each framework's closest graph/computed primitive.
| Framework | Median (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|
| Levit | 23 | 29.7 | 19-114 | 17.1 | 100 | OK |
| Vanilla | 62 | 82.5 | 53-503 | 56.4 | 100 | OK |
| GetX | 122 | 130.4 | 106-267 | 26.2 | 100 | OK |
| Riverpod | 141 | 166.9 | 106-631 | 72.8 | 100 | OK |
| BLoC | 403 | 429.3 | 364-800 | 78.4 | 100 | OK |

## Fan Out Update
Classification: Comparative
| Framework | Median (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|
| Vanilla | 9 | 14.8 | 6-78 | 12.7 | 100 | OK |
| Levit | 17 | 26.4 | 13-172 | 20.8 | 100 | OK |
| GetX | 22 | 31.0 | 17-211 | 25.7 | 100 | OK |
| Riverpod | 26 | 38.5 | 7-274 | 32.1 | 100 | OK |
| BLoC | 547 | 573.8 | 485-1122 | 100.2 | 100 | OK |

## Fan In Update
Classification: Comparative
| Framework | Median (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|
| Vanilla | 8 | 10.7 | 6-43 | 6.9 | 100 | OK |
| Levit | 9 | 16.8 | 4-387 | 38.7 | 100 | OK |
| Riverpod | 20 | 30.6 | 6-208 | 31.9 | 100 | OK |
| GetX | 20 | 29.1 | 14-149 | 25.2 | 100 | OK |
| BLoC | 29 | 38.6 | 21-221 | 26.6 | 100 | OK |

## Async Computed
Classification: Approximate  
Note: Measures sequential async recomputation using each framework's closest async primitive.
| Framework | Median (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|
| Vanilla | 907 | 1061.9 | 654-2835 | 402.7 | 100 | OK |
| GetX | 1166 | 1283.1 | 803-2564 | 407.6 | 100 | OK |
| Levit | 1524 | 1688.8 | 1116-3236 | 455.1 | 100 | OK |
| Riverpod | 1936 | 2052.1 | 1192-4277 | 576.7 | 100 | OK |
| BLoC | 2104 | 2244.2 | 1242-4122 | 666.8 | 100 | OK |

## Batch vs Un-batched
Classification: Feature Demo  
Note: Levit uses a native batching primitive; others measure un-batched closest equivalents.
| Framework | Median (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|
| BLoC | 19 | 31.9 | 15-306 | 45.4 | 100 | OK |
| GetX | 23 | 34.8 | 19-177 | 30.0 | 100 | OK |
| Levit | 37 | 70.7 | 26-583 | 97.7 | 100 | OK |
| Riverpod | 73 | 111.1 | 68-634 | 88.2 | 100 | OK |
| Vanilla | 168 | 209.5 | 141-727 | 103.1 | 100 | OK |

## Scoped DI Lookup
Classification: Feature Demo  
Note: DI containers are not first-class primitives in every framework.
| Framework | Median (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|
| BLoC | 6 | 8.0 | 6-38 | 5.3 | 100 | OK |
| Vanilla | 9 | 22.8 | 6-172 | 28.9 | 100 | OK |
| Riverpod | 25 | 37.2 | 22-263 | 32.3 | 100 | OK |
| Levit | 49 | 52.0 | 47-89 | 9.1 | 100 | OK |
| GetX | 133 | 155.1 | 121-514 | 56.6 | 100 | OK |

## Computed Chain (Deep Propagation)
Classification: Approximate  
Note: Approximates deep computed propagation with each framework's closest primitive.
| Framework | Median (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|
| Levit | 135 | 137.7 | 119-202 | 16.8 | 100 | OK |
| Vanilla | 229 | 246.5 | 209-689 | 61.6 | 100 | OK |
| GetX | 463 | 648.2 | 364-4059 | 459.3 | 100 | OK |
| BLoC | 33586 | 34220.9 | 31689-56305 | 3413.8 | 100 | OK |
| Riverpod | 115781 | 128349.5 | 104721-404769 | 43848.2 | 100 | OK |

## Large List Update (UI)
Classification: Comparative
| Framework | Median (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|
| Levit | 904 | 1028.1 | 652-2163 | 367.4 | 100 | OK |
| Vanilla | 1023 | 1224.2 | 676-6937 | 803.4 | 100 | OK |
| GetX | 1067 | 1287.8 | 664-3804 | 636.7 | 100 | OK |
| Riverpod | 1753 | 2073.7 | 964-6314 | 985.5 | 100 | OK |
| BLoC | 5116 | 9397.9 | 1277-156272 | 17281.0 | 100 | OK |

## Deep Tree Propagation (UI)
Classification: Comparative
| Framework | Median (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|
| Levit | 475 | 570.4 | 370-1408 | 209.6 | 100 | OK |
| GetX | 489 | 567.4 | 345-1552 | 222.6 | 100 | OK |
| BLoC | 504 | 594.9 | 388-1312 | 209.3 | 100 | OK |
| Vanilla | 638 | 694.5 | 382-1405 | 238.6 | 100 | OK |
| Riverpod | 1150 | 1590.2 | 594-6274 | 1109.8 | 100 | OK |

## Dynamic Grid Churn (UI)
Classification: Comparative
| Framework | Median (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|
| GetX | 7249 | 7410.1 | 6257-10157 | 699.8 | 100 | OK |
| Levit | 7601 | 8768.1 | 6139-41904 | 4267.8 | 100 | OK |
| Riverpod | 7701 | 7795.8 | 6597-10627 | 779.9 | 100 | OK |
| BLoC | 7906 | 8408.2 | 6696-18411 | 1712.7 | 100 | OK |
| Vanilla | 10461 | 10910.7 | 6921-25557 | 2800.5 | 100 | OK |

## Animated State - 60fps (UI)
Classification: Comparative
| Framework | Median (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|
| Vanilla | 166 | 193.0 | 143-616 | 66.2 | 100 | OK |
| Riverpod | 192 | 253.5 | 150-1301 | 166.7 | 100 | OK |
| GetX | 206 | 249.8 | 160-816 | 121.9 | 100 | OK |
| BLoC | 239 | 281.3 | 189-811 | 116.1 | 100 | OK |
| Levit | 260 | 332.8 | 199-1967 | 224.4 | 100 | OK |

