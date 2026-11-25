#!/usr/bin/env python3
"""Repeat the unchanged native dashboard in before/after, after/before order.

This does not alter benchmark configurations, warmup, frame capture or workloads.
Run on an otherwise idle machine. CPU sampling is a separate profile-mode step.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sources(root):
    paths = set()
    for base in [root / 'packages', root / 'benchmarks']:
        paths.update(p for p in base.rglob('*.dart')
                     if 'lib' in p.relative_to(base).parts
                     and not any(x in p.parts for x in ['build', '.dart_tool']))
        paths.update(base.rglob('pubspec.lock'))
        paths.update(base.rglob('pubspec.yaml'))
        paths.update(base.rglob('pubspec_overrides.yaml'))
    return {str(p.relative_to(root)): digest(p) for p in sorted(paths)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--before-root', type=Path, required=True)
    parser.add_argument('--after-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--flutter', required=True)
    parser.add_argument('--mode', choices=['profile', 'release'], default='release')
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument('--chain-only', action='store_true', help='Isolate the unchanged Levit/vanilla chain cases')
    selection.add_argument('--grid-only', action='store_true', help='Isolate the existing grid case without changing its workload or order')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    roots = {'before': args.before_root.resolve(), 'after': args.after_root.resolve()}
    metadata = {'mode': args.mode, 'order': ['before', 'after', 'after', 'before'], 'gridOnly': args.grid_only, 'chainOnly': args.chain_only,
                'inputs': {}, 'runs': []}
    for label, root in roots.items():
        manifest = sources(root)
        source_digest = hashlib.sha256(json.dumps(manifest, sort_keys=True).encode()).hexdigest()
        metadata['inputs'][label] = {'root': str(root), 'digest': source_digest, 'files': manifest}
    before_files = metadata['inputs']['before']['files']
    after_files = metadata['inputs']['after']['files']
    for path, sha in before_files.items():
        if path.startswith('benchmarks/'):
            if after_files.get(path) != sha:
                raise RuntimeError(f'Benchmark source/lock changed: {path}')
    (args.output / 'inputs.json').write_text(json.dumps(metadata['inputs'], indent=2) + '\n')
    binaries = {}
    for label, root in roots.items():
        print(f'Building {label} {args.mode}', flush=True)
        with (args.output / f'{label}-build.log').open('w') as log:
            subprocess.run([args.flutter, 'build', 'macos', f'--{args.mode}',
                            '--target=lib/compare_chain_workload.dart' if args.chain_only else
                            '--target=lib/compare_grid_workload.dart' if args.grid_only else '--target=lib/compare_app_workloads.dart',
                            '--dart-define=BENCHMARK_REVISION=' + metadata['inputs'][label]['digest']],
                           cwd=root / 'benchmarks', stdout=log, stderr=subprocess.STDOUT,
                           check=True, timeout=600)
        binary = root / f'benchmarks/build/macos/Build/Products/{args.mode.title()}/benchmarks.app/Contents/MacOS/benchmarks'
        binaries[label] = binary
        metadata['inputs'][label]['binarySha256'] = digest(binary)
        # Flutter keeps Dart AOT separately from the executable shell.
        framework = binary.parent.parent / 'Frameworks/App.framework/App'
        metadata['inputs'][label]['dartAotSha256'] = digest(framework)
    geometry = None
    for number, label in enumerate(metadata['order'], 1):
        print(f'Running {number}: {label} {args.mode}', flush=True)
        name = f'{number:02}-{label}'
        log_path = args.output / f'{name}.log'
        env = dict(os.environ, LEVIT_PERFORMANCE_RUN='1', LEVIT_DIAGNOSTICS='off')
        started = time.time()
        with log_path.open('w') as log:
            subprocess.run([str(binaries[label])], env=env, stdout=log,
                           stderr=subprocess.STDOUT, check=True, timeout=600)
        lines = log_path.read_text().splitlines()
        payloads = [s.split('APP_COMPARISON_JSON:', 1)[1] for s in lines
                    if 'APP_COMPARISON_JSON:' in s]
        if len(payloads) != 1:
            raise RuntimeError(f'Expected one complete result in {log_path}')
        report = json.loads(payloads[0])
        environment = report['environment']
        current_geometry = [environment['display'], environment['refreshRate']]
        if geometry is None:
            geometry = current_geometry
        if geometry != current_geometry:
            raise RuntimeError(f'Viewport/refresh changed: {current_geometry} != {geometry}')
        if environment['sourceRevision'] != metadata['inputs'][label]['digest']:
            raise RuntimeError('Binary source identity mismatch')
        if report['methodologyVersion'] != 2 or len(report['results']) != (2 if args.chain_only else 5 if args.grid_only else 60):
            raise RuntimeError('Unexpected methodology or result count')
        if environment['iterations'] != 50 or environment['warmupIterations'] != 5:
            raise RuntimeError('Workload sample count changed')
        (args.output / f'{name}.json').write_text(json.dumps(report, indent=2) + '\n')
        metadata['runs'].append({'name': name, 'seconds': time.time() - started,
                                 'geometry': current_geometry})
        (args.output / 'comparison.json').write_text(json.dumps(metadata, indent=2) + '\n')
        print(f'Validated {name}: {len(report["results"])} cases; {current_geometry}', flush=True)
    print('Comparison complete', flush=True)


if __name__ == '__main__':
    main()
