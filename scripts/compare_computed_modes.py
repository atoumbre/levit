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
WORKLOADS = [
    'Diamond Graph (Observed Updates)', 'Fan Out Update', 'Fan In Update',
    'Async Computed', 'Batch vs Un-batched', 'Computed Chain (Deep Propagation)',
]


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def summarize(reports):
    result_sets = [{r['benchmark']: r for r in report['results']}
                   for report in reports]
    summary = {}
    names = dict.fromkeys(name for results in result_sets for name in results)
    for name in names:
        selected = [(report, results[name]) for report, results in zip(reports, result_sets)
                    if name in results]
        selected_reports = [report for report, _ in selected]
        metrics = {}
        for metric, calc in [
            ('p50', statistics.median),
            ('p95', lambda values: sorted(values)[math.ceil(len(values) * .95) - 1]),
        ]:
            values = [calc(result['samplesMicros']) for _, result in selected]
            dynamic = [v for v, report in zip(values, selected_reports)
                       if report['dependencyMode'] == 'dynamic']
            static = [v for v, report in zip(values, selected_reports)
                      if report['dependencyMode'] == 'static']
            paired = []
            for i in range(0, len(selected_reports), 2):
                by_mode = {selected_reports[j]['dependencyMode']: values[j] for j in (i, i + 1)}
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
    parser.add_argument('--isolate-workloads', action='store_true',
                        help='Run each workload in a fresh process (48 processes total)')
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
    schedule = [(mode, order, workload)
                for workload in (WORKLOADS if args.isolate_workloads else [None])
                for mode, order in SCHEDULE]
    metadata = {'buildMode': args.mode, 'sourceDigest': source_digest,
                'binaryHashes': binary_hashes, 'schedule': schedule,
                'isolatedWorkloads': args.isolate_workloads, 'runs': []}
    reports = []
    reference_environment = None
    for number, (mode, order, workload) in enumerate(schedule, 1):
        name = f'{number:02}-{mode}-{order}'
        print(f'Running {name}', flush=True)
        if {'shell': digest(binary), 'dartAot': digest(aot)} != binary_hashes:
            raise RuntimeError('Binary changed between runs')
        started = time.time()
        env = dict(os.environ, LEVIT_PERFORMANCE_RUN='1', LEVIT_DIAGNOSTICS='off',
                   LEVIT_COMPUTED_MODE=mode, LEVIT_COMPUTED_REVERSE=str(int(order == 'reverse')))
        env.pop('LEVIT_COMPUTED_WORKLOAD', None)
        if workload is not None:
            env['LEVIT_COMPUTED_WORKLOAD'] = workload
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
        expected_count = 1 if workload is not None else 6
        if (report['methodologyVersion'] != 2 or len(report['results']) != expected_count or
                report['dependencyMode'] != mode or report['workloadOrder'] != order or
                report['workloadSelection'] != workload or
                report['workloadConfig'] != WORKLOAD_CONFIG):
            raise RuntimeError('Unexpected workload, tracking mode or methodology')
        names = [result['benchmark'] for result in report['results']]
        forward_names = [workload] if workload is not None else WORKLOADS
        expected_names = forward_names if order == 'forward' else forward_names[::-1]
        if len(set(names)) != expected_count or names != expected_names or environment['benchmarks'] != names:
            raise RuntimeError('Missing, duplicated or reordered workload')
        for result in report['results']:
            if (not result['success'] or result['error'] is not None or
                    len(result['samplesMicros']) != 50 or result['warmupIterations'] != 5 or
                    result['framework'] != 'levit' or
                    result['implementation'] != f'Levit ({mode})' or result['frameTimings']):
                raise RuntimeError(f'Invalid computed result: {result["benchmark"]}')
        reports.append(report)
        metadata['runs'].append({'name': name, 'workload': workload,
                                 'seconds': time.time() - started})
        write_json(output / 'comparison.json', metadata)
        print(f'Validated {name}: {expected_count} cases / {expected_count * 50} samples / awaited cleanup', flush=True)
    changed = [path for path, sha in manifest.items() if digest(root / path) != sha]
    if changed:
        raise RuntimeError(f'Source inputs changed during comparison: {changed}')
    write_json(output / 'summary.json', summarize(reports))
    print('Complete: 48 cases, 2400 samples, four paired comparisons per workload.', flush=True)


if __name__ == '__main__':
    main()
