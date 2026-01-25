# Benchmark Results
Date: 2026-01-29 05:41:01.360776

## Rapid State Mutation
| Framework | Time (µs) | Status |
|---|---|---|
| Levit | 6403 | OK |
| Vanilla | 8525 | OK |
| GetX | 15078 | OK |
| BLoC | 34840 | OK |
| Riverpod | 102771 | OK |

## Complex Graph (Diamond)
| Framework | Time (µs) | Status |
|---|---|---|
| BLoC | 2964 | OK |
| Levit | 5952 | OK |
| Vanilla | 6105 | OK |
| GetX | 8065 | OK |
| Riverpod | 93621 | OK |

## Fan Out Update
| Framework | Time (µs) | Status |
|---|---|---|
| Vanilla | 42 | OK |
| Levit | 113 | OK |
| GetX | 157 | OK |
| Riverpod | 278 | OK |
| BLoC | 289 | OK |

## Fan In Update
| Framework | Time (µs) | Status |
|---|---|---|
| Levit | 31 | OK |
| Vanilla | 46 | OK |
| Riverpod | 60 | OK |
| GetX | 76 | OK |
| BLoC | 139 | OK |

## Async Computed
| Framework | Time (µs) | Status |
|---|---|---|
| Vanilla | 2815 | OK |
| Levit | 3123 | OK |
| Riverpod | 4095 | OK |
| BLoC | 5364 | OK |
| GetX | 5368 | OK |

## Batch vs Un-batched
| Framework | Time (µs) | Status |
|---|---|---|
| Levit | 89 | OK |
| GetX | 131 | OK |
| Vanilla | 160 | OK |
| BLoC | 166 | OK |
| Riverpod | 1568 | OK |

## Scoped DI Lookup
| Framework | Time (µs) | Status |
|---|---|---|
| Vanilla | 43 | OK |
| BLoC | 43 | OK |
| Levit | 53 | OK |
| Riverpod | 218 | OK |
| GetX | 2700 | OK |

## Large List Update (UI)
| Framework | Time (µs) | Status |
|---|---|---|
| GetX | 14598 | OK |
| Riverpod | 14824 | OK |
| Levit | 14911 | OK |
| BLoC | 15008 | OK |
| Vanilla | 15306 | OK |

## Deep Tree Propagation (UI)
| Framework | Time (µs) | Status |
|---|---|---|
| GetX | 14778 | OK |
| BLoC | 14784 | OK |
| Levit | 14790 | OK |
| Riverpod | 14924 | OK |
| Vanilla | 14941 | OK |

## Dynamic Grid Churn (UI)
| Framework | Time (µs) | Status |
|---|---|---|
| Levit | 15143 | OK |
| Vanilla | 15169 | OK |
| Riverpod | 15196 | OK |
| GetX | 15303 | OK |
| BLoC | 15603 | OK |

## Animated State - 60fps (UI)
| Framework | Time (µs) | Status |
|---|---|---|
| BLoC | 13794 | OK |
| Levit | 14067 | OK |
| Riverpod | 14120 | OK |
| GetX | 14371 | OK |
| Vanilla | 14448 | OK |

