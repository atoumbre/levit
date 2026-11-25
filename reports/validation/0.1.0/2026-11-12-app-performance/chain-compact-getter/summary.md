# Repeated dashboard comparison

Two independent processes per revision; raw within-run samples are not independent trials.

Negative change means lower elapsed time. All values are microseconds.

| Benchmark | Framework | Metric | Before 1 p50 | After 1 p50 | After 2 p50 | Before 2 p50 | Paired changes |
|---|---|---|---:|---:|---:|---:|---|
| Computed Chain (Deep Propagation) | vanilla | wallUs | 30694 | 30602.5 | 31321.5 | 30827 | -0.3%, +1.6% |
| Computed Chain (Deep Propagation) | levit | wallUs | 27900.5 | 26952 | 26227 | 27616.5 | -3.4%, -5.0% |
