"""Run the original comparison driver with a fixed, verified display geometry.

Usage: python3 run_native.py REFERENCE_ROOT NEW_OUTPUT_DIRECTORY BEFORE_ROOT
Only off-display launches may be repeated. Preserve their output and abort on
any other validation error. All timed work and driver assertions stay intact.
"""
import json
from pathlib import Path
import runpy
import subprocess
import sys
from unittest.mock import patch


def main():
    output = Path(sys.argv[2]).resolve()
    output.mkdir(parents=True, exist_ok=False)
    expected = ([1600.0, 1200.0], 2.0, 1, 120.0)
    launch = subprocess.run
    rejected = 0

    def run_on_display(args, **kwargs):
        nonlocal rejected
        for _ in range(4):
            result = launch(args, **kwargs)
            if result.returncode:
                return result
            lines = [line for line in result.stdout.splitlines()
                     if 'LEVIT_PERFORMANCE_JSON:' in line]
            if len(lines) != 1:
                return result
            data = json.loads(lines[0].split('LEVIT_PERFORMANCE_JSON:', 1)[1])
            layout = (data['physicalSize'], data['pixelRatio'],
                      data['displayId'], data['refreshRate'])
            if layout == expected:
                return result
            rejected += 1
            path = output / f'rejected-display-{rejected}.log'
            path.write_text(result.stdout + result.stderr)
            print(f'Repeating off-display launch {layout}, retained in {path.name}', flush=True)
        raise RuntimeError('Could not obtain the designated display after four launches')

    driver = Path(__file__).resolve().parents[4] / 'benchmarks/tool/compare_release_performance.py'
    with patch.object(subprocess, 'run', run_on_display):
        runpy.run_path(str(driver), run_name='__main__')


if __name__ == '__main__':
    main()
