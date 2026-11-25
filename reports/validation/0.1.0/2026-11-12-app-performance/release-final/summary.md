# Repeated dashboard comparison

Generated run artifacts were removed during cleanup on 2026-11-24. Historical artifact paths refer to Git commit `bd1a095`.


Two independent processes per revision; raw within-run samples are not independent trials.

Negative change means lower elapsed time. All values are microseconds.

| Benchmark | Framework | Metric | Before 1 p50 | After 1 p50 | After 2 p50 | Before 2 p50 | Paired changes |
|---|---|---|---:|---:|---:|---:|---|
| Rapid State Mutation | vanilla | wallUs | 13010.5 | 12968 | 12818 | 12632 | -0.3%, +1.5% |
| Rapid State Mutation | levit | wallUs | 13787.5 | 13833 | 14087 | 13888.5 | +0.3%, +1.4% |
| Rapid State Mutation | getx | wallUs | 20828.5 | 19873.5 | 19913.5 | 20557 | -4.6%, -3.1% |
| Rapid State Mutation | bloc | wallUs | 79952 | 81795.5 | 82082 | 80675.5 | +2.3%, +1.7% |
| Rapid State Mutation | riverpod | wallUs | 112370 | 111368 | 110781 | 109644 | -0.9%, +1.0% |
| Diamond Graph (Observed Updates) | levit | wallUs | 1379.5 | 1333.5 | 1981.5 | 2208.5 | -3.3%, -10.3% |
| Diamond Graph (Observed Updates) | getx | wallUs | 117744 | 118044 | 119274 | 114110 | +0.3%, +4.5% |
| Diamond Graph (Observed Updates) | bloc | wallUs | 5554.5 | 5880.5 | 5817.5 | 4969 | +5.9%, +17.1% |
| Diamond Graph (Observed Updates) | riverpod | wallUs | 10278 | 10138 | 10252.5 | 10237 | -1.4%, +0.2% |
| Diamond Graph (Observed Updates) | vanilla | wallUs | 1313 | 1139 | 1293.5 | 1674.5 | -13.3%, -22.8% |
| Fan Out Update | getx | wallUs | 234.5 | 71.5 | 75 | 38.5 | -69.5%, +94.8% |
| Fan Out Update | bloc | wallUs | 754.5 | 738 | 743.5 | 779 | -2.2%, -4.6% |
| Fan Out Update | riverpod | wallUs | 1863 | 1734.5 | 1805.5 | 1787 | -6.9%, +1.0% |
| Fan Out Update | vanilla | wallUs | 62.5 | 63.5 | 74.5 | 58 | +1.6%, +28.4% |
| Fan Out Update | levit | wallUs | 1043 | 649.5 | 650 | 827 | -37.7%, -21.4% |
| Fan In Update | bloc | wallUs | 123 | 109.5 | 110 | 147.5 | -11.0%, -25.4% |
| Fan In Update | riverpod | wallUs | 763 | 664.5 | 956.5 | 954 | -12.9%, +0.3% |
| Fan In Update | vanilla | wallUs | 46 | 43.5 | 49 | 46 | -5.4%, +6.5% |
| Fan In Update | levit | wallUs | 527.5 | 193.5 | 94 | 521 | -63.3%, -82.0% |
| Fan In Update | getx | wallUs | 54.5 | 54.5 | 54.5 | 58.5 | +0.0%, -6.8% |
| Async Computed | riverpod | wallUs | 3821 | 4454.5 | 3958.5 | 4001.5 | +16.6%, -1.1% |
| Async Computed | vanilla | wallUs | 2703.5 | 2645.5 | 2955.5 | 4536 | -2.1%, -34.8% |
| Async Computed | levit | wallUs | 4778.5 | 3033 | 4462.5 | 4639.5 | -36.5%, -3.8% |
| Async Computed | getx | wallUs | 3924.5 | 4109 | 3346 | 4003.5 | +4.7%, -16.4% |
| Async Computed | bloc | wallUs | 4597.5 | 4587.5 | 4447.5 | 4418 | -0.2%, +0.7% |
| Batch vs Un-batched | vanilla | wallUs | 306 | 485.5 | 284.5 | 347.5 | +58.7%, -18.1% |
| Batch vs Un-batched | levit | wallUs | 128.5 | 96 | 141.5 | 191 | -25.3%, -25.9% |
| Batch vs Un-batched | getx | wallUs | 83.5 | 96 | 152.5 | 163.5 | +15.0%, -6.7% |
| Batch vs Un-batched | bloc | wallUs | 128 | 95 | 136 | 140.5 | -25.8%, -3.2% |
| Batch vs Un-batched | riverpod | wallUs | 908 | 1132.5 | 1166 | 920.5 | +24.7%, +26.7% |
| Warm Root DI Lookup | levit | wallUs | 110 | 135 | 85 | 79 | +22.7%, +7.6% |
| Warm Root DI Lookup | getx | wallUs | 3602 | 2942 | 2360.5 | 2918 | -18.3%, -19.1% |
| Warm Root DI Lookup | bloc | wallUs | 58 | 87.5 | 86 | 91 | +50.9%, -5.5% |
| Warm Root DI Lookup | riverpod | wallUs | 168.5 | 159 | 249 | 263 | -5.6%, -5.3% |
| Warm Root DI Lookup | vanilla | wallUs | 62.5 | 35 | 93 | 88 | -44.0%, +5.7% |
| Computed Chain (Deep Propagation) | getx | wallUs | 73900.5 | 77146.5 | 48016.5 | 48373.5 | +4.4%, -0.7% |
| Computed Chain (Deep Propagation) | bloc | wallUs | 48340 | 48570.5 | 48239 | 47710 | +0.5%, +1.1% |
| Computed Chain (Deep Propagation) | riverpod | wallUs | 464296 | 454894 | 449726 | 463986 | -2.0%, -3.1% |
| Computed Chain (Deep Propagation) | vanilla | wallUs | 30465.5 | 31219.5 | 31070.5 | 30030 | +2.5%, +3.5% |
| Computed Chain (Deep Propagation) | levit | wallUs | 27107 | 25003 | 21207 | 26508.5 | -7.8%, -20.0% |
| Virtualized List: Visible Row Update (UI) | bloc | wallUs | 7058.5 | 6893 | 6162 | 6422 | -2.3%, -4.0% |
| Virtualized List: Visible Row Update (UI) | bloc | buildUs | 2397 | 2204 | 666.5 | 2516.5 | -8.1%, -73.5% |
| Virtualized List: Visible Row Update (UI) | bloc | rasterUs | 1792.5 | 1648 | 629 | 1936.5 | -8.1%, -67.5% |
| Virtualized List: Visible Row Update (UI) | riverpod | wallUs | 6994.5 | 6765.5 | 6285 | 6222.5 | -3.3%, +1.0% |
| Virtualized List: Visible Row Update (UI) | riverpod | buildUs | 1640.5 | 2198.5 | 1740.5 | 1961.5 | +34.0%, -11.3% |
| Virtualized List: Visible Row Update (UI) | riverpod | rasterUs | 1309.5 | 1968 | 1616.5 | 1644 | +50.3%, -1.7% |
| Virtualized List: Visible Row Update (UI) | vanilla | wallUs | 6776.5 | 6895 | 6157.5 | 6573 | +1.7%, -6.3% |
| Virtualized List: Visible Row Update (UI) | vanilla | buildUs | 2006 | 1312.5 | 1808.5 | 2030.5 | -34.6%, -10.9% |
| Virtualized List: Visible Row Update (UI) | vanilla | rasterUs | 1808 | 1200 | 1525 | 1819 | -33.6%, -16.2% |
| Virtualized List: Visible Row Update (UI) | levit | wallUs | 6860.5 | 6927.5 | 6341.5 | 6106 | +1.0%, +3.9% |
| Virtualized List: Visible Row Update (UI) | levit | buildUs | 1681 | 2089.5 | 2069.5 | 1407 | +24.3%, +47.1% |
| Virtualized List: Visible Row Update (UI) | levit | rasterUs | 1603 | 1749.5 | 1972.5 | 1414.5 | +9.1%, +39.4% |
| Virtualized List: Visible Row Update (UI) | getx | wallUs | 6841.5 | 6926.5 | 6386.5 | 6051 | +1.2%, +5.5% |
| Virtualized List: Visible Row Update (UI) | getx | buildUs | 1646 | 1604 | 1396.5 | 1277 | -2.6%, +9.4% |
| Virtualized List: Visible Row Update (UI) | getx | rasterUs | 1575.5 | 1397 | 1276.5 | 1201.5 | -11.3%, +6.2% |
| Nested Leaf Rebuild (UI) | riverpod | wallUs | 6938 | 7043.5 | 6333 | 6344.5 | +1.5%, -0.2% |
| Nested Leaf Rebuild (UI) | riverpod | buildUs | 1206.5 | 1483.5 | 1457.5 | 1431.5 | +23.0%, +1.8% |
| Nested Leaf Rebuild (UI) | riverpod | rasterUs | 1320.5 | 1570.5 | 1613.5 | 1412.5 | +18.9%, +14.2% |
| Nested Leaf Rebuild (UI) | vanilla | wallUs | 6735 | 6831.5 | 6163 | 6145.5 | +1.4%, +0.3% |
| Nested Leaf Rebuild (UI) | vanilla | buildUs | 1089.5 | 1258.5 | 1227.5 | 1017.5 | +15.5%, +20.6% |
| Nested Leaf Rebuild (UI) | vanilla | rasterUs | 1184.5 | 1550 | 1598 | 1334.5 | +30.9%, +19.7% |
| Nested Leaf Rebuild (UI) | levit | wallUs | 6818 | 6810.5 | 6170.5 | 5993 | -0.1%, +3.0% |
| Nested Leaf Rebuild (UI) | levit | buildUs | 1438.5 | 1113 | 1252 | 1377 | -22.6%, -9.1% |
| Nested Leaf Rebuild (UI) | levit | rasterUs | 1743 | 1389 | 1661.5 | 1827.5 | -20.3%, -9.1% |
| Nested Leaf Rebuild (UI) | getx | wallUs | 7069 | 6779 | 5929.5 | 6031.5 | -4.1%, -1.7% |
| Nested Leaf Rebuild (UI) | getx | buildUs | 896 | 1370.5 | 1376 | 1246 | +53.0%, +10.4% |
| Nested Leaf Rebuild (UI) | getx | rasterUs | 1096 | 1794.5 | 1727.5 | 1492 | +63.7%, +15.8% |
| Nested Leaf Rebuild (UI) | bloc | wallUs | 6838 | 6852 | 6050 | 5927 | +0.2%, +2.1% |
| Nested Leaf Rebuild (UI) | bloc | buildUs | 1263.5 | 1116.5 | 1344 | 413.5 | -11.6%, +225.0% |
| Nested Leaf Rebuild (UI) | bloc | rasterUs | 1639 | 1084.5 | 1474.5 | 519 | -33.8%, +184.1% |
| Dynamic Grid Churn (UI) | vanilla | wallUs | 6955.5 | 7000.5 | 12719 | 7045.5 | +0.6%, +80.5% |
| Dynamic Grid Churn (UI) | vanilla | buildUs | 3943.5 | 4964.5 | 5584 | 4778.5 | +25.9%, +16.9% |
| Dynamic Grid Churn (UI) | vanilla | rasterUs | 1116.5 | 1349.5 | 1527 | 1409 | +20.9%, +8.4% |
| Dynamic Grid Churn (UI) | levit | wallUs | 7474.5 | 7340 | 8003 | 7147.5 | -1.8%, +12.0% |
| Dynamic Grid Churn (UI) | levit | buildUs | 4398 | 4301 | 4717 | 4826 | -2.2%, -2.3% |
| Dynamic Grid Churn (UI) | levit | rasterUs | 1285.5 | 953 | 1350.5 | 1297 | -25.9%, +4.1% |
| Dynamic Grid Churn (UI) | getx | wallUs | 6938.5 | 6915.5 | 6896 | 9405 | -0.3%, -26.7% |
| Dynamic Grid Churn (UI) | getx | buildUs | 4295.5 | 4841.5 | 4596 | 5471.5 | +12.7%, -16.0% |
| Dynamic Grid Churn (UI) | getx | rasterUs | 1242 | 1226.5 | 1336 | 1416 | -1.2%, -5.6% |
| Dynamic Grid Churn (UI) | bloc | wallUs | 6986 | 6991 | 7078 | 6884 | +0.1%, +2.8% |
| Dynamic Grid Churn (UI) | bloc | buildUs | 4390.5 | 4878.5 | 3276 | 4224.5 | +11.1%, -22.5% |
| Dynamic Grid Churn (UI) | bloc | rasterUs | 1290 | 1346 | 1033 | 1257.5 | +4.3%, -17.9% |
| Dynamic Grid Churn (UI) | riverpod | wallUs | 8710 | 6797 | 7338 | 10478.5 | -22.0%, -30.0% |
| Dynamic Grid Churn (UI) | riverpod | buildUs | 5400 | 4262 | 4458.5 | 5749.5 | -21.1%, -22.5% |
| Dynamic Grid Churn (UI) | riverpod | rasterUs | 1130 | 1207 | 1241 | 1480 | +6.8%, -16.1% |
| Progress Bar State Update (UI) | levit | wallUs | 6978 | 6998.5 | 6302.5 | 6221.5 | +0.3%, +1.3% |
| Progress Bar State Update (UI) | levit | buildUs | 829 | 969 | 880.5 | 773 | +16.9%, +13.9% |
| Progress Bar State Update (UI) | levit | rasterUs | 1532.5 | 1766 | 1768.5 | 1591 | +15.2%, +11.2% |
| Progress Bar State Update (UI) | getx | wallUs | 7001 | 6919.5 | 6356.5 | 6015.5 | -1.2%, +5.7% |
| Progress Bar State Update (UI) | getx | buildUs | 815 | 746.5 | 1005 | 668 | -8.4%, +50.4% |
| Progress Bar State Update (UI) | getx | rasterUs | 1404 | 1397 | 1920 | 1217.5 | -0.5%, +57.7% |
| Progress Bar State Update (UI) | bloc | wallUs | 7012.5 | 6847 | 6170 | 6333 | -2.4%, -2.6% |
| Progress Bar State Update (UI) | bloc | buildUs | 922.5 | 856 | 803.5 | 931.5 | -7.2%, -13.7% |
| Progress Bar State Update (UI) | bloc | rasterUs | 1806 | 1482 | 1418 | 1833 | -17.9%, -22.6% |
| Progress Bar State Update (UI) | riverpod | wallUs | 6853 | 7244 | 6149 | 6121.5 | +5.7%, +0.4% |
| Progress Bar State Update (UI) | riverpod | buildUs | 766 | 929 | 812 | 763.5 | +21.3%, +6.4% |
| Progress Bar State Update (UI) | riverpod | rasterUs | 1163.5 | 1727 | 1711.5 | 1312.5 | +48.4%, +30.4% |
| Progress Bar State Update (UI) | vanilla | wallUs | 6911 | 6930.5 | 5927 | 6340 | +0.3%, -6.5% |
| Progress Bar State Update (UI) | vanilla | buildUs | 793 | 912 | 860.5 | 894 | +15.0%, -3.7% |
| Progress Bar State Update (UI) | vanilla | rasterUs | 1515.5 | 1640 | 1469 | 1724.5 | +8.2%, -14.8% |
