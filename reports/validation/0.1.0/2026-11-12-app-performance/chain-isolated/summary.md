# Repeated dashboard comparison

Two independent processes per revision; raw within-run samples are not independent trials.

Negative change means lower elapsed time. All values are microseconds.

| Benchmark | Framework | Metric | Before 1 p50 | After 1 p50 | After 2 p50 | Before 2 p50 | Paired changes |
|---|---|---|---:|---:|---:|---:|---|
| Computed Chain (Deep Propagation) | vanilla | wallUs | 32934.5 | 30657.5 | 31771 | 31383 | -6.9%, +1.2% |
| Computed Chain (Deep Propagation) | levit | wallUs | 27740 | 32105.5 | 30816 | 27298 | +15.7%, +12.9% |
