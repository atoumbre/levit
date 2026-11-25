# Benchmark Results
Date: 2026-09-06 08:27:26.505643

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
| OS Version | Version 26.6.2 (Build 25G83) |
| Dart Version | 3.12.2 |
| CPU Threads | 8 |
| Locale | en_US |

## Rapid State Mutation
Classification: Comparative
| Framework | Median (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|
| Levit | 402 | 413.6 | 385-543 | 32.6 | 100 | OK |
| Vanilla | 441 | 463.0 | 405-788 | 60.2 | 100 | OK |
| BLoC | 455 | 464.8 | 413-696 | 42.7 | 100 | OK |
| GetX | 619 | 626.0 | 599-726 | 27.4 | 100 | OK |
| Riverpod | 3592 | 3710.1 | 3342-11976 | 876.8 | 100 | OK |

## Complex Graph (Diamond)
Classification: Approximate  
Note: Uses each framework's closest graph/computed primitive.
| Framework | Median (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|
| Levit | 21 | 26.3 | 19-112 | 12.9 | 100 | OK |
| Vanilla | 52 | 59.7 | 50-239 | 25.8 | 100 | OK |
| Riverpod | 121 | 134.8 | 104-318 | 38.0 | 100 | OK |
| GetX | 122 | 126.5 | 90-289 | 29.9 | 100 | OK |
| BLoC | 351 | 367.9 | 341-574 | 44.3 | 100 | OK |

## Fan Out Update
Classification: Comparative
| Framework | Median (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|
| Vanilla | 13 | 13.4 | 7-55 | 6.9 | 100 | OK |
| GetX | 17 | 19.9 | 14-59 | 7.6 | 100 | OK |
| Levit | 19 | 24.1 | 14-73 | 11.3 | 100 | OK |
| Riverpod | 26 | 39.6 | 5-281 | 38.6 | 100 | OK |
| BLoC | 500 | 520.2 | 465-852 | 61.3 | 100 | OK |

## Fan In Update
Classification: Comparative
| Framework | Median (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|
| Vanilla | 7 | 7.9 | 5-20 | 2.4 | 100 | OK |
| Levit | 8 | 12.2 | 3-111 | 15.4 | 100 | OK |
| Riverpod | 15 | 17.4 | 5-55 | 5.9 | 100 | OK |
| GetX | 16 | 17.6 | 13-73 | 6.9 | 100 | OK |
| BLoC | 26 | 29.4 | 20-144 | 15.4 | 100 | OK |

## Async Computed
Classification: Approximate  
Note: Measures sequential async recomputation using each framework's closest async primitive.
| Framework | Median (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|
| Vanilla | 691 | 714.7 | 609-1019 | 84.6 | 100 | OK |
| GetX | 877 | 900.8 | 766-1276 | 103.6 | 100 | OK |
| Levit | 1342 | 1432.3 | 1108-3811 | 400.7 | 100 | OK |
| BLoC | 1361 | 1441.4 | 1092-4458 | 411.9 | 100 | OK |
| Riverpod | 1426 | 1458.7 | 1129-2288 | 226.2 | 100 | OK |

## Batch vs Un-batched
Classification: Feature Demo  
Note: Levit uses a native batching primitive; others measure un-batched closest equivalents.
| Framework | Median (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|
| BLoC | 17 | 18.9 | 15-56 | 5.5 | 100 | OK |
| GetX | 21 | 25.6 | 19-107 | 12.8 | 100 | OK |
| Levit | 30 | 37.8 | 24-162 | 20.9 | 100 | OK |
| Riverpod | 72 | 81.7 | 63-287 | 29.4 | 100 | OK |
| Vanilla | 146 | 150.4 | 131-243 | 18.9 | 100 | OK |

## Scoped DI Lookup
Classification: Feature Demo  
Note: DI containers are not first-class primitives in every framework.
| Framework | Median (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|
| BLoC | 6 | 7.7 | 6-63 | 6.1 | 100 | OK |
| Vanilla | 6 | 8.6 | 6-133 | 13.6 | 100 | OK |
| Riverpod | 22 | 26.3 | 21-139 | 15.0 | 100 | OK |
| Levit | 52 | 142.3 | 45-7584 | 753.4 | 100 | OK |
| GetX | 128 | 139.4 | 114-314 | 33.7 | 100 | OK |

## Computed Chain (Deep Propagation)
Classification: Approximate  
Note: Approximates deep computed propagation with each framework's closest primitive.
| Framework | Median (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|
| Levit | 119 | 124.8 | 118-231 | 14.0 | 100 | OK |
| Vanilla | 196 | 209.5 | 190-384 | 35.9 | 100 | OK |
| GetX | 377 | 386.1 | 350-493 | 30.9 | 100 | OK |
| BLoC | 36443 | 40045.8 | 31706-131666 | 12356.8 | 100 | OK |
| Riverpod | 95152 | 97565.7 | 90615-225653 | 14741.8 | 100 | OK |

## Large List Update (UI)
Classification: Comparative
| Framework | Median (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|
| Vanilla | 795 | 896.9 | 660-2312 | 288.6 | 100 | OK |
| GetX | 852 | 923.5 | 656-2203 | 291.6 | 100 | OK |
| Levit | 887 | 966.7 | 642-2098 | 310.3 | 100 | OK |
| Riverpod | 1069 | 1214.3 | 739-3080 | 414.2 | 100 | OK |
| BLoC | 1644 | 1705.6 | 982-3623 | 499.3 | 100 | OK |

## Deep Tree Propagation (UI)
Classification: Comparative
| Framework | Median (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|
| GetX | 650 | 688.5 | 526-1130 | 129.5 | 100 | OK |
| BLoC | 654 | 719.7 | 569-1228 | 152.2 | 100 | OK |
| Levit | 734 | 760.9 | 549-1308 | 163.4 | 100 | OK |
| Vanilla | 764 | 804.4 | 550-1384 | 175.2 | 100 | OK |
| Riverpod | 982 | 1154.6 | 665-10997 | 1038.9 | 100 | OK |

## Dynamic Grid Churn (UI)
Classification: Comparative
| Framework | Median (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|
| GetX | 7244 | 7309.5 | 5960-9415 | 760.1 | 100 | OK |
| BLoC | 7521 | 7573.4 | 6092-9727 | 745.9 | 100 | OK |
| Riverpod | 7540 | 7647.9 | 6471-9996 | 654.7 | 100 | OK |
| Levit | 7906 | 9100.5 | 6461-38386 | 5118.8 | 100 | OK |
| Vanilla | 8234 | 8261.1 | 6604-10483 | 873.1 | 100 | OK |

## Animated State - 60fps (UI)
Classification: Comparative
| Framework | Median (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |
|---|---|---|---|---|---|---|
| Vanilla | 167 | 193.6 | 143-727 | 76.9 | 100 | OK |
| Riverpod | 195 | 231.0 | 154-1067 | 111.5 | 100 | OK |
| GetX | 243 | 286.4 | 179-1595 | 168.2 | 100 | OK |
| Levit | 291 | 350.0 | 222-1579 | 202.8 | 100 | OK |
| BLoC | 297 | 381.3 | 192-1796 | 280.6 | 100 | OK |

