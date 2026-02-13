# Benchmark Results
Date: 2026-02-13 11:10:07.017313

## Rapid State Mutation
| Framework | Time (µs) | Status |
|---|---|---|
| Levit | 5943 | OK |
| Vanilla | 7816 | OK |
| GetX | 15828 | OK |
| BLoC | 40426 | OK |
| Riverpod | 113575 | OK |

## Complex Graph (Diamond)
| Framework | Time (µs) | Status |
|---|---|---|
| BLoC | 277 | OK |
| Levit | 728 | OK |
| Vanilla | 966 | OK |
| GetX | 977 | OK |
| Riverpod | 10633 | OK |

## Fan Out Update
| Framework | Time (µs) | Status |
|---|---|---|
| GetX | 27 | OK |
| Vanilla | 35 | OK |
| Levit | 76 | OK |
| Riverpod | 134 | OK |
| BLoC | 218 | OK |

## Fan In Update
| Framework | Time (µs) | Status |
|---|---|---|
| Levit | 24 | OK |
| Vanilla | 25 | OK |
| GetX | 31 | OK |
| Riverpod | 38 | OK |
| BLoC | 68 | OK |

## Async Computed
| Framework | Time (µs) | Status |
|---|---|---|
| GetX | 2350 | OK |
| Levit | 2451 | OK |
| BLoC | 2493 | OK |
| Vanilla | 2738 | OK |
| Riverpod | 2950 | OK |

## Batch vs Un-batched
| Framework | Time (µs) | Status |
|---|---|---|
| GetX | 40 | OK |
| BLoC | 54 | OK |
| Levit | 61 | OK |
| Vanilla | 127 | OK |
| Riverpod | 493 | OK |

## Scoped DI Lookup
| Framework | Time (µs) | Status |
|---|---|---|
| BLoC | 10 | OK |
| Vanilla | 11 | OK |
| Levit | 17 | OK |
| Riverpod | 47 | OK |
| GetX | 1381 | OK |

## Computed Chain (Deep Propagation)
| Framework | Time (µs) | Status |
|---|---|---|
| Vanilla | 32188 | OK |
| Levit | 32404 | OK |
| GetX | 49979 | OK |
| BLoC | 52926 | OK |
| Riverpod | 507927 | OK |

## Large List Update (UI)
| Framework | Time (µs) | Status |
|---|---|---|
| Levit | 6858 | OK |
| Vanilla | 6883 | OK |
| Riverpod | 6980 | OK |
| GetX | 7088 | OK |
| BLoC | 3615871 | OK |

## Deep Tree Propagation (UI)
| Framework | Time (µs) | Status |
|---|---|---|
| GetX | 6665 | OK |
| Levit | 6846 | OK |
| Vanilla | 7026 | OK |
| Riverpod | 69105 | OK |
| BLoC | 83960 | OK |

## Dynamic Grid Churn (UI)
| Framework | Time (µs) | Status |
|---|---|---|
| Levit | 7026 | OK |
| GetX | 7149 | OK |
| BLoC | 7157 | OK |
| Vanilla | 7293 | OK |
| Riverpod | 7304 | OK |

## Animated State - 60fps (UI)
| Framework | Time (µs) | Status |
|---|---|---|
| BLoC | 6672 | OK |
| Vanilla | 6675 | OK |
| Riverpod | 6713 | OK |
| GetX | 6734 | OK |
| Levit | 6787 | OK |

