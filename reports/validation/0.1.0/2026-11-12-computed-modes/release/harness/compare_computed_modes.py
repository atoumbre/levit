#!/usr/bin/env python3
"""Compare all six app computed workloads using one binary and both tracking modes.

Run on an otherwise idle machine. Four adjacent pairs balance mode order and
workload order. Each process retains the normal 5 warmups / 50 samples / 10ms idle.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import statistics
import subprocess
import time

from compare_app_performance import digest, sources


SCHEDULE = [
    ('dynamic', 'forward'), ('static', 'forward'),
    ('static', 'reverse'), ('dynamic', 'reverse'),
    ('static', 'forward'), ('dynamic', 'forward'),
    ('dynamic', 'reverse'), ('static', 'reverse'),
]
WORKLOAD_CONFIG = {
    'diamondUpdates': 10000, 'fanOutDependents': 1000, 'fanInInputs': 1000,
    'asyncUpdates': 100, 'batchUpdates': 1000, 'chainDepth': 1000,
    'chainUpdates': 1000,
}


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def summarize(reports):
    result_sets = [{r['benchmark']: r for r in report['results']}
                   for report in reports]
    summary = {}
    for name in result_sets[0]:
        metrics = {}
        for metric, calc in [
            ('p50', statistics.median),
            ('p95', lambda values: sorted(values)[math.ceil(len(values) * .95) - 1]),
        ]:
            values = [calc(results[name]['samplesMicros']) for results in result_sets]
            dynamic = [v for v, report in zip(values, reports)
                       if report['dependencyMode'] == 'dynamic']
            static = [v for v, report in zip(values, reports)
                      if report['dependencyMode'] == 'static']
            paired = []
            for i in range(0, len(reports), 2):
                by_mode = {reports[j]['dependencyMode']: values[j] for j in (i, i + 1)}
                paired.append((by_mode['static'] / by_mode['dynamic'] - 1) * 100)
            metrics[metric] = {
                'dynamicRunsUs': dynamic, 'staticRunsUs': static,
                'dynamicUs': statistics.median(dynamic),
                'staticUs': statistics.median(static),
                'staticVsDynamicPercent': (statistics.median(static) /
                                           statistics.median(dynamic) - 1) * 100,
                'pairedPercent': paired,
            }
        summary[name] = metrics
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--flutter', required=True)
    parser.add_argument('--mode', choices=['release', 'profile'], default='release')
    args = parser.parse_args()
    root = args.root.resolve()
    output = args.output.resolve()
    if output.exists() and any(output.iterdir()):
        raise RuntimeError('Use an empty evidence directory; existing runs are preserved.')
    output.mkdir(parents=True, exist_ok=True)
    manifest = sources(root)
    extra = [root / 'scripts/compare_computed_modes.py',
             root / 'scripts/compare_app_performance.py',
             root / 'pubspec.yaml', root / 'pubspec.lock']
    extra.extend((root / 'benchmarks/macos/Runner').rglob('*'))
    extra.append(root / 'benchmarks/macos/Runner.xcodeproj/project.pbxproj')
    for path in extra:
        if path.is_file():
            manifest[str(path.relative_to(root))] = digest(path)
    source_digest = hashlib.sha256(json.dumps(manifest, sort_keys=True).encode()).hexdigest()
    inputs = {'sourceDigest': source_digest, 'files': manifest}
    write_json(output / 'inputs.json', inputs)
    print(f'Building one {args.mode} binary: {source_digest}', flush=True)
    with (output / 'build.log').open('w') as log:
        subprocess.run([args.flutter, 'build', 'macos', f'--{args.mode}',
                        '--target=lib/compare_computed_modes.dart',
                        f'--dart-define=BENCHMARK_REVISION={source_digest}'],
                       cwd=root / 'benchmarks', stdout=log, stderr=subprocess.STDOUT,
                       check=True, timeout=600)
    binary = root / f'benchmarks/build/macos/Build/Products/{args.mode.title()}/benchmarks.app/Contents/MacOS/benchmarks'
    aot = binary.parent.parent / 'Frameworks/App.framework/App'
    binary_hashes = {'shell': digest(binary), 'dartAot': digest(aot)}
    metadata = {'buildMode': args.mode, 'sourceDigest': source_digest,
                'binaryHashes': binary_hashes, 'schedule': SCHEDULE, 'runs': []}
    reports = []
    reference_environment = None
    forward_names = None
    for number, (mode, order) in enumerate(SCHEDULE, 1):
        name = f'{number:02}-{mode}-{order}'
        print(f'Running {name}', flush=True)
        if {'shell': digest(binary), 'dartAot': digest(aot)} != binary_hashes:
            raise RuntimeError('Binary changed between runs')
        started = time.time()
        env = dict(os.environ, LEVIT_PERFORMANCE_RUN='1', LEVIT_DIAGNOSTICS='off',
                   LEVIT_COMPUTED_MODE=mode, LEVIT_COMPUTED_REVERSE=str(int(order == 'reverse')))
        log_path = output / f'{name}.log'
        with log_path.open('w') as log:
            subprocess.run([str(binary)], env=env, stdout=log,
                           stderr=subprocess.STDOUT, check=True, timeout=180)
        lines = log_path.read_text().splitlines()
        payloads = [line.split('COMPUTED_COMPARISON_JSON:', 1)[1] for line in lines
                    if 'COMPUTED_COMPARISON_JSON:' in line]
        if len(payloads) != 1:
            raise RuntimeError(f'Expected one completed report: {log_path}')
        report = json.loads(payloads[0])
        write_json(output / f'{name}.json', report)
        environment = report['environment']
        comparable_environment = {key: value for key, value in environment.items()
                                  if key not in ['capturedAt', 'benchmarks']}
        if reference_environment is None:
            reference_environment = comparable_environment
        if comparable_environment != reference_environment:
            raise RuntimeError('Device, viewport, SDK or build identity changed')
        if (environment['sourceRevision'] != source_digest or
                environment['buildMode'] != args.mode or
                environment['benchmarkProfile'] != 'production' or
                environment['iterations'] != 50 or environment['warmupIterations'] != 5):
            raise RuntimeError('Unexpected measurement environment')
        if (report['methodologyVersion'] != 2 or len(report['results']) != 6 or
                report['dependencyMode'] != mode or report['workloadOrder'] != order or
                report['workloadConfig'] != WORKLOAD_CONFIG):
            raise RuntimeError('Unexpected workload, tracking mode or methodology')
        names = [result['benchmark'] for result in report['results']]
        if forward_names is None:
            forward_names = names
        expected_names = forward_names if order == 'forward' else forward_names[::-1]
        if len(set(names)) != 6 or names != expected_names or environment['benchmarks'] != names:
            raise RuntimeError('Missing, duplicated or reordered workload')
        for result in report['results']:
            if (not result['success'] or result['error'] is not None or
                    len(result['samplesMicros']) != 50 or result['warmupIterations'] != 5 or
                    result['framework'] != 'levit' or
                    result['implementation'] != f'Levit ({mode})' or result['frameTimings']):
                raise RuntimeError(f'Invalid computed result: {result["benchmark"]}')
        reports.append(report)
        metadata['runs'].append({'name': name, 'seconds': time.time() - started})
        write_json(output / 'comparison.json', metadata)
        print(f'Validated {name}: six cases / 300 samples / awaited cleanup', flush=True)
    changed = [path for path, sha in manifest.items() if digest(root / path) != sha]
    if changed:
        raise RuntimeError(f'Source inputs changed during comparison: {changed}')
    write_json(output / 'summary.json', summarize(reports))
    print('Complete: 48 cases, 2400 samples, four paired comparisons per workload.', flush=True)


if __name__ == '__main__':
    main()
