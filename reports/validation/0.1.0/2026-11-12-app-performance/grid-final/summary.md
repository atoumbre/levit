# Repeated dashboard comparison

Two independent processes per revision; raw within-run samples are not independent trials.

Negative change means lower elapsed time. All values are microseconds.

| Benchmark | Framework | Metric | Before 1 p50 | After 1 p50 | After 2 p50 | Before 2 p50 | Paired changes |
|---|---|---|---:|---:|---:|---:|---|
| Dynamic Grid Churn (UI) | vanilla | wallUs | 6572.5 | 8951 | 8697.5 | 8396 | +36.2%, +3.6% |
| Dynamic Grid Churn (UI) | vanilla | buildUs | 3337 | 4381.5 | 4669.5 | 4890.5 | +31.3%, -4.5% |
| Dynamic Grid Churn (UI) | vanilla | rasterUs | 1039.5 | 1024.5 | 994.5 | 910.5 | -1.4%, +9.2% |
| Dynamic Grid Churn (UI) | levit | wallUs | 6117.5 | 12229 | 6546.5 | 13932 | +99.9%, -53.0% |
| Dynamic Grid Churn (UI) | levit | buildUs | 4242 | 6739 | 4289 | 6371.5 | +58.9%, -32.7% |
| Dynamic Grid Churn (UI) | levit | rasterUs | 1222 | 973 | 1168.5 | 1532 | -20.4%, -23.7% |
| Dynamic Grid Churn (UI) | getx | wallUs | 7111 | 6240 | 10939 | 5915 | -12.2%, +84.9% |
| Dynamic Grid Churn (UI) | getx | buildUs | 4613.5 | 3343.5 | 5515 | 4209.5 | -27.5%, +31.0% |
| Dynamic Grid Churn (UI) | getx | rasterUs | 1318 | 1065 | 1347.5 | 1159.5 | -19.2%, +16.2% |
| Dynamic Grid Churn (UI) | bloc | wallUs | 7001 | 12928.5 | 11551.5 | 11631 | +84.7%, -0.7% |
| Dynamic Grid Churn (UI) | bloc | buildUs | 3454.5 | 7436.5 | 5914.5 | 5599.5 | +115.3%, +5.6% |
| Dynamic Grid Churn (UI) | bloc | rasterUs | 1170 | 982 | 1480.5 | 1261 | -16.1%, +17.4% |
| Dynamic Grid Churn (UI) | riverpod | wallUs | 10040.5 | 6555.5 | 13059 | 9664 | -34.7%, +35.1% |
| Dynamic Grid Churn (UI) | riverpod | buildUs | 5438 | 4088 | 5211.5 | 5593 | -24.8%, -6.8% |
| Dynamic Grid Churn (UI) | riverpod | rasterUs | 1431.5 | 1184 | 1380 | 1248.5 | -17.3%, +10.5% |
