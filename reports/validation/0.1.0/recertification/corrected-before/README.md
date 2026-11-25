# Rejected display-mismatch probe

Generated run artifacts were removed during cleanup on 2026-11-24. Historical artifact paths refer to Git commit `bd1a095`.


Baseline teardown and process isolation were corrected here. All 16 individual processes passed, but the full matrix failed its display check (1600×1200 at 2× versus 800×600 at 1×). These timings are excluded from certification. The final host pins screen placement and checks display identity/refresh rate; accepted measurements are in `../final/`. The reference teardown test remains valid functional evidence.
