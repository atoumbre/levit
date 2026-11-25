# Rejected display-mismatch probe

Baseline teardown and process isolation were corrected here. All 16 individual processes passed, but the full matrix failed its display check (1600×1200 at 2× versus 800×600 at 1×). These timings are excluded from certification. The final host pins screen placement and checks display identity/refresh rate; accepted measurements are in `../final/`. The reference teardown test remains valid functional evidence.
