# Excluded comparison

This attempt is excluded from performance conclusions. A focused Dart test
compilation was inadvertently started while the native matrix was still running.
Even though the test did not load, its compiler work could affect measurements.
The matrix finished before the stop request found a running process. All raw
results are retained but excluded.
The entire sustained-warmup matrix must be rerun without concurrent checks.
