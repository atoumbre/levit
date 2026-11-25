# Repeated dashboard comparison

Generated run artifacts were removed during cleanup on 2026-11-24. Historical artifact paths refer to Git commit `bd1a095`.


Two independent processes per revision; raw within-run samples are not independent trials.

Negative change means lower elapsed time. All values are microseconds.

| Benchmark | Framework | Metric | Before 1 p50 | After 1 p50 | After 2 p50 | Before 2 p50 | Paired changes |
|---|---|---|---:|---:|---:|---:|---|
| Dynamic Grid Churn (UI) | vanilla | wallUs | 6986 | 7038 | 6834.5 | 6806.5 | +0.7%, +0.4% |
| Dynamic Grid Churn (UI) | vanilla | buildUs | 4428.5 | 4239 | 3209 | 3936.5 | -4.3%, -18.5% |
| Dynamic Grid Churn (UI) | vanilla | rasterUs | 1145.5 | 1107.5 | 1016.5 | 1043 | -3.3%, -2.5% |
| Dynamic Grid Churn (UI) | levit | wallUs | 6981.5 | 7114.5 | 9146 | 6976 | +1.9%, +31.1% |
| Dynamic Grid Churn (UI) | levit | buildUs | 5026 | 4770 | 4027.5 | 4512 | -5.1%, -10.7% |
| Dynamic Grid Churn (UI) | levit | rasterUs | 1434.5 | 1204 | 1009 | 1321 | -16.1%, -23.6% |
| Dynamic Grid Churn (UI) | getx | wallUs | 6966 | 7318.5 | 6856.5 | 7236.5 | +5.1%, -5.3% |
| Dynamic Grid Churn (UI) | getx | buildUs | 4277.5 | 4852 | 4745 | 4926 | +13.4%, -3.7% |
| Dynamic Grid Churn (UI) | getx | rasterUs | 1111.5 | 1360 | 1399.5 | 1351 | +22.4%, +3.6% |
| Dynamic Grid Churn (UI) | bloc | wallUs | 7055.5 | 6909.5 | 6970.5 | 6991 | -2.1%, -0.3% |
| Dynamic Grid Churn (UI) | bloc | buildUs | 5052 | 4501 | 3667.5 | 4195 | -10.9%, -12.6% |
| Dynamic Grid Churn (UI) | bloc | rasterUs | 1410.5 | 1304 | 1122 | 1112.5 | -7.6%, +0.9% |
| Dynamic Grid Churn (UI) | riverpod | wallUs | 10488.5 | 6954 | 6914.5 | 7361 | -33.7%, -6.1% |
| Dynamic Grid Churn (UI) | riverpod | buildUs | 6233.5 | 4896.5 | 4696 | 5471.5 | -21.4%, -14.2% |
| Dynamic Grid Churn (UI) | riverpod | rasterUs | 1214 | 1362.5 | 1318 | 1396 | +12.2%, -5.6% |
