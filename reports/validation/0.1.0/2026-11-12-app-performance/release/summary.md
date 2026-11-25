# Repeated dashboard comparison

Generated run artifacts were removed during cleanup on 2026-11-24. Historical artifact paths refer to Git commit `bd1a095`.


Two independent processes per revision; raw within-run samples are not independent trials.

Negative change means lower elapsed time. All values are microseconds.

| Benchmark | Framework | Metric | Before 1 p50 | After 1 p50 | After 2 p50 | Before 2 p50 | Paired changes |
|---|---|---|---:|---:|---:|---:|---|
| Rapid State Mutation | vanilla | wallUs | 12852.5 | 13145 | 12812.5 | 12911.5 | +2.3%, -0.8% |
| Rapid State Mutation | levit | wallUs | 13987.5 | 13945 | 14341 | 13909.5 | -0.3%, +3.1% |
| Rapid State Mutation | getx | wallUs | 20612.5 | 20002 | 20076.5 | 20457.5 | -3.0%, -1.9% |
| Rapid State Mutation | bloc | wallUs | 82054 | 83578.5 | 82441 | 81556.5 | +1.9%, +1.1% |
| Rapid State Mutation | riverpod | wallUs | 110719 | 112534 | 110712 | 109507 | +1.6%, +1.1% |
| Diamond Graph (Observed Updates) | levit | wallUs | 1360.5 | 1323 | 907.5 | 1410.5 | -2.8%, -35.7% |
| Diamond Graph (Observed Updates) | getx | wallUs | 122343 | 116178 | 116635 | 123116 | -5.0%, -5.3% |
| Diamond Graph (Observed Updates) | bloc | wallUs | 5813.5 | 5514 | 5493.5 | 5203 | -5.2%, +5.6% |
| Diamond Graph (Observed Updates) | riverpod | wallUs | 9570.5 | 9938 | 10046 | 9823.5 | +3.8%, +2.3% |
| Diamond Graph (Observed Updates) | vanilla | wallUs | 1559 | 1935.5 | 2147 | 686 | +24.2%, +213.0% |
| Fan Out Update | getx | wallUs | 70.5 | 81 | 90.5 | 87 | +14.9%, +4.0% |
| Fan Out Update | bloc | wallUs | 697.5 | 730.5 | 752 | 209 | +4.7%, +259.8% |
| Fan Out Update | riverpod | wallUs | 1732.5 | 1223.5 | 968.5 | 551.5 | -29.4%, +75.6% |
| Fan Out Update | vanilla | wallUs | 60.5 | 52 | 50 | 54.5 | -14.0%, -8.3% |
| Fan Out Update | levit | wallUs | 636.5 | 451 | 759.5 | 1053 | -29.1%, -27.9% |
| Fan In Update | bloc | wallUs | 124 | 94 | 153.5 | 65.5 | -24.2%, +134.4% |
| Fan In Update | riverpod | wallUs | 735.5 | 240.5 | 945.5 | 914.5 | -67.3%, +3.4% |
| Fan In Update | vanilla | wallUs | 38 | 25 | 50.5 | 28 | -34.2%, +80.4% |
| Fan In Update | levit | wallUs | 388.5 | 72.5 | 85.5 | 144 | -81.3%, -40.6% |
| Fan In Update | getx | wallUs | 77 | 28 | 43.5 | 91 | -63.6%, -52.2% |
| Async Computed | riverpod | wallUs | 3387 | 2794.5 | 4359 | 3609.5 | -17.5%, +20.8% |
| Async Computed | vanilla | wallUs | 3353 | 2889.5 | 3693 | 1741.5 | -13.8%, +112.1% |
| Async Computed | levit | wallUs | 3588.5 | 3227 | 4661.5 | 2106.5 | -10.1%, +121.3% |
| Async Computed | getx | wallUs | 4046.5 | 2342.5 | 4659.5 | 2929.5 | -42.1%, +59.1% |
| Async Computed | bloc | wallUs | 4286.5 | 3836 | 4322 | 3714.5 | -10.5%, +16.4% |
| Batch vs Un-batched | vanilla | wallUs | 231 | 236 | 375 | 122 | +2.2%, +207.4% |
| Batch vs Un-batched | levit | wallUs | 84.5 | 86 | 136 | 75.5 | +1.8%, +80.1% |
| Batch vs Un-batched | getx | wallUs | 73.5 | 105 | 128.5 | 50 | +42.9%, +157.0% |
| Batch vs Un-batched | bloc | wallUs | 138 | 96 | 129.5 | 45.5 | -30.4%, +184.6% |
| Batch vs Un-batched | riverpod | wallUs | 889.5 | 661 | 677.5 | 304.5 | -25.7%, +122.5% |
| Warm Root DI Lookup | levit | wallUs | 99 | 62 | 86 | 43 | -37.4%, +100.0% |
| Warm Root DI Lookup | getx | wallUs | 2003.5 | 1555 | 2344.5 | 1306.5 | -22.4%, +79.4% |
| Warm Root DI Lookup | bloc | wallUs | 31 | 36 | 71 | 32 | +16.1%, +121.9% |
| Warm Root DI Lookup | riverpod | wallUs | 74 | 144.5 | 209.5 | 124 | +95.3%, +69.0% |
| Warm Root DI Lookup | vanilla | wallUs | 58.5 | 71 | 86 | 38 | +21.4%, +126.3% |
| Computed Chain (Deep Propagation) | getx | wallUs | 66828.5 | 73170.5 | 74553 | 74337 | +9.5%, +0.3% |
| Computed Chain (Deep Propagation) | bloc | wallUs | 48212.5 | 49120.5 | 48126.5 | 50494.5 | +1.9%, -4.7% |
| Computed Chain (Deep Propagation) | riverpod | wallUs | 456081 | 464500 | 457588 | 481596 | +1.8%, -5.0% |
| Computed Chain (Deep Propagation) | vanilla | wallUs | 30184.5 | 31186 | 30900.5 | 31280 | +3.3%, -1.2% |
| Computed Chain (Deep Propagation) | levit | wallUs | 26448.5 | 31779.5 | 29129 | 27071.5 | +20.2%, +7.6% |
| Virtualized List: Visible Row Update (UI) | bloc | wallUs | 6993.5 | 6651 | 6884 | 6831.5 | -4.9%, +0.8% |
| Virtualized List: Visible Row Update (UI) | bloc | buildUs | 2275.5 | 2231 | 1588 | 955.5 | -2.0%, +66.2% |
| Virtualized List: Visible Row Update (UI) | bloc | rasterUs | 1545 | 1289 | 1340.5 | 751 | -16.6%, +78.5% |
| Virtualized List: Visible Row Update (UI) | riverpod | wallUs | 7018.5 | 6875.5 | 6896.5 | 7099 | -2.0%, -2.9% |
| Virtualized List: Visible Row Update (UI) | riverpod | buildUs | 1787.5 | 951.5 | 1638 | 1166 | -46.8%, +40.5% |
| Virtualized List: Visible Row Update (UI) | riverpod | rasterUs | 1421.5 | 930.5 | 1516 | 716 | -34.5%, +111.7% |
| Virtualized List: Visible Row Update (UI) | vanilla | wallUs | 6811 | 6864.5 | 6678 | 6800.5 | +0.8%, -1.8% |
| Virtualized List: Visible Row Update (UI) | vanilla | buildUs | 1887 | 644 | 1750.5 | 1461 | -65.9%, +19.8% |
| Virtualized List: Visible Row Update (UI) | vanilla | rasterUs | 1624.5 | 639 | 1408 | 1009.5 | -60.7%, +39.5% |
| Virtualized List: Visible Row Update (UI) | levit | wallUs | 6843 | 6849.5 | 7033.5 | 6838 | +0.1%, +2.9% |
| Virtualized List: Visible Row Update (UI) | levit | buildUs | 2040.5 | 1058.5 | 903 | 643 | -48.1%, +40.4% |
| Virtualized List: Visible Row Update (UI) | levit | rasterUs | 1762.5 | 1035 | 878.5 | 631.5 | -41.3%, +39.1% |
| Virtualized List: Visible Row Update (UI) | getx | wallUs | 6822 | 6866 | 6870.5 | 6970.5 | +0.6%, -1.4% |
| Virtualized List: Visible Row Update (UI) | getx | buildUs | 1081 | 1011 | 1962 | 700 | -6.5%, +180.3% |
| Virtualized List: Visible Row Update (UI) | getx | rasterUs | 1053 | 985 | 1720.5 | 681 | -6.5%, +152.6% |
| Nested Leaf Rebuild (UI) | riverpod | wallUs | 6919 | 6948 | 6952.5 | 6913 | +0.4%, +0.6% |
| Nested Leaf Rebuild (UI) | riverpod | buildUs | 1546 | 1288.5 | 1026.5 | 999.5 | -16.7%, +2.7% |
| Nested Leaf Rebuild (UI) | riverpod | rasterUs | 1625.5 | 1098.5 | 1012 | 945.5 | -32.4%, +7.0% |
| Nested Leaf Rebuild (UI) | vanilla | wallUs | 6787.5 | 6855.5 | 6890 | 6842.5 | +1.0%, +0.7% |
| Nested Leaf Rebuild (UI) | vanilla | buildUs | 1252 | 962 | 1141.5 | 825.5 | -23.2%, +38.3% |
| Nested Leaf Rebuild (UI) | vanilla | rasterUs | 1612.5 | 1041.5 | 1464 | 954 | -35.4%, +53.5% |
| Nested Leaf Rebuild (UI) | levit | wallUs | 6902 | 6815 | 7117.5 | 6852.5 | -1.3%, +3.9% |
| Nested Leaf Rebuild (UI) | levit | buildUs | 1241.5 | 1378.5 | 1340 | 943 | +11.0%, +42.1% |
| Nested Leaf Rebuild (UI) | levit | rasterUs | 1672 | 1540.5 | 1606.5 | 950.5 | -7.9%, +69.0% |
| Nested Leaf Rebuild (UI) | getx | wallUs | 6975.5 | 6882.5 | 7100.5 | 7012 | -1.3%, +1.3% |
| Nested Leaf Rebuild (UI) | getx | buildUs | 1037.5 | 781 | 1053.5 | 1045.5 | -24.7%, +0.8% |
| Nested Leaf Rebuild (UI) | getx | rasterUs | 1380 | 952.5 | 1466.5 | 1144 | -31.0%, +28.2% |
| Nested Leaf Rebuild (UI) | bloc | wallUs | 7138.5 | 6961.5 | 6987.5 | 6908 | -2.5%, +1.2% |
| Nested Leaf Rebuild (UI) | bloc | buildUs | 848.5 | 1055 | 1383 | 978.5 | +24.3%, +41.3% |
| Nested Leaf Rebuild (UI) | bloc | rasterUs | 1085 | 1238.5 | 1762 | 1076.5 | +14.1%, +63.7% |
| Dynamic Grid Churn (UI) | vanilla | wallUs | 6992 | 7016.5 | 7032 | 7027.5 | +0.4%, +0.1% |
| Dynamic Grid Churn (UI) | vanilla | buildUs | 4869 | 3940 | 4251.5 | 4124 | -19.1%, +3.1% |
| Dynamic Grid Churn (UI) | vanilla | rasterUs | 1353.5 | 1190 | 1251 | 1271.5 | -12.1%, -1.6% |
| Dynamic Grid Churn (UI) | levit | wallUs | 6981 | 7065.5 | 6980.5 | 7036.5 | +1.2%, -0.8% |
| Dynamic Grid Churn (UI) | levit | buildUs | 4111 | 4339 | 4403 | 3482.5 | +5.5%, +26.4% |
| Dynamic Grid Churn (UI) | levit | rasterUs | 1215.5 | 1326 | 1332.5 | 1114.5 | +9.1%, +19.6% |
| Dynamic Grid Churn (UI) | getx | wallUs | 6902.5 | 6835 | 6973 | 7038 | -1.0%, -0.9% |
| Dynamic Grid Churn (UI) | getx | buildUs | 4106.5 | 4156 | 4132.5 | 4047.5 | +1.2%, +2.1% |
| Dynamic Grid Churn (UI) | getx | rasterUs | 1262 | 1280 | 1216.5 | 1226 | +1.4%, -0.8% |
| Dynamic Grid Churn (UI) | bloc | wallUs | 6995 | 6998 | 11700 | 7185 | +0.0%, +62.8% |
| Dynamic Grid Churn (UI) | bloc | buildUs | 4265.5 | 3691 | 6362 | 3929 | -13.5%, +61.9% |
| Dynamic Grid Churn (UI) | bloc | rasterUs | 1321.5 | 1080 | 990.5 | 1144 | -18.3%, -13.4% |
| Dynamic Grid Churn (UI) | riverpod | wallUs | 7197.5 | 6832.5 | 6916 | 6796 | -5.1%, +1.8% |
| Dynamic Grid Churn (UI) | riverpod | buildUs | 4600 | 4385.5 | 4652.5 | 3982.5 | -4.7%, +16.8% |
| Dynamic Grid Churn (UI) | riverpod | rasterUs | 1281.5 | 1335.5 | 1270.5 | 1212.5 | +4.2%, +4.8% |
| Progress Bar State Update (UI) | levit | wallUs | 6953 | 6838.5 | 6973.5 | 6927 | -1.6%, +0.7% |
| Progress Bar State Update (UI) | levit | buildUs | 840.5 | 551.5 | 677.5 | 645.5 | -34.4%, +5.0% |
| Progress Bar State Update (UI) | levit | rasterUs | 1544.5 | 977 | 1158.5 | 1059 | -36.7%, +9.4% |
| Progress Bar State Update (UI) | getx | wallUs | 7045.5 | 6894 | 6882.5 | 6981 | -2.2%, -1.4% |
| Progress Bar State Update (UI) | getx | buildUs | 678.5 | 442.5 | 682.5 | 478 | -34.8%, +42.8% |
| Progress Bar State Update (UI) | getx | rasterUs | 1159 | 739 | 1324.5 | 850.5 | -36.2%, +55.7% |
| Progress Bar State Update (UI) | bloc | wallUs | 7112 | 6951.5 | 6833 | 6773.5 | -2.3%, +0.9% |
| Progress Bar State Update (UI) | bloc | buildUs | 939 | 639.5 | 755 | 652.5 | -31.9%, +15.7% |
| Progress Bar State Update (UI) | bloc | rasterUs | 1748 | 1092.5 | 1407.5 | 1086 | -37.5%, +29.6% |
| Progress Bar State Update (UI) | riverpod | wallUs | 6933 | 6909 | 6955.5 | 6913.5 | -0.3%, +0.6% |
| Progress Bar State Update (UI) | riverpod | buildUs | 685 | 804.5 | 875.5 | 504 | +17.4%, +73.7% |
| Progress Bar State Update (UI) | riverpod | rasterUs | 1181.5 | 1347 | 1664.5 | 842 | +14.0%, +97.7% |
| Progress Bar State Update (UI) | vanilla | wallUs | 7056 | 7040 | 6900.5 | 6787.5 | -0.2%, +1.7% |
| Progress Bar State Update (UI) | vanilla | buildUs | 895.5 | 1005 | 796.5 | 618.5 | +12.2%, +28.8% |
| Progress Bar State Update (UI) | vanilla | rasterUs | 1743.5 | 1606.5 | 1335 | 1112 | -7.9%, +20.1% |
