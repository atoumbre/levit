#!/usr/bin/env python3
"""Compare the current app workloads against exact pub.dev release archives.

Build isolated snapshots first (--prepare-only), then measure (--measure-only).
No runtime library is modified. Compatibility edits are outside timed work and
saved as patches. Each workload/mode/revision runs in a fresh native process.
"""
import argparse
import difflib
import hashlib
import io
import json
import math
import os
from pathlib import Path
import re
import shutil
import statistics
import subprocess
import tarfile
import tempfile
import time
import urllib.request

from compare_app_performance import digest, sources
from compare_computed_modes import WORKLOADS


EXTRA_WORKLOADS = [
    'Rapid State Mutation', 'Warm Root DI Lookup',
    'Virtualized List: Visible Row Update (UI)', 'Nested Leaf Rebuild (UI)',
    'Dynamic Grid Churn (UI)', 'Progress Bar State Update (UI)',
]
CASES = [(name, mode) for name in WORKLOADS for mode in ['dynamic', 'static']]
CASES += [(name, 'default') for name in EXTRA_WORKLOADS]
PAIR_ORDERS = [('published', 'current'), ('current', 'published'),
               ('current', 'published'), ('published', 'current')]


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def download(url):
    with urllib.request.urlopen(url, timeout=60) as response:
        return response.read()


def manifest(root):
    files = sources(root)
    for path in (root / 'benchmarks/macos').rglob('*'):
        if path.is_file() and not {'build', 'Pods', 'ephemeral'}.intersection(path.parts):
            files[str(path.relative_to(root))] = digest(path)
    return files


def prepare(root, output, flutter):
    if (output / 'prepared.json').exists():
        raise RuntimeError('Prepared evidence exists; use --measure-only or a new output directory.')
    registry = json.loads((output / 'published-packages.json').read_text())
    stage = Path(tempfile.mkdtemp(prefix='levit-published-comparison-', dir='/private/tmp'))
    package_paths = {}
    for path in (root / 'packages').rglob('pubspec.yaml'):
        if {'build', '.dart_tool'}.intersection(path.parts):
            continue
        match = re.search(r'^name:\s*(\w+)\s*$', path.read_text(), re.M)
        if match and match[1] in registry:
            package_paths[match[1]] = path.parent.relative_to(root)
    if set(package_paths) != set(registry):
        raise RuntimeError('Could not locate all runtime package roots')
    archives = output / 'archives'
    archives.mkdir(exist_ok=True)
    for name, package in registry.items():
        path = archives / f'{name}-{package["version"]}.tar.gz'
        if not path.exists():
            path.write_bytes(download(package['archiveUrl']))
        if digest(path) != package['archiveSha256']:
            raise RuntimeError(f'Published archive checksum mismatch: {name}')
    inputs = {'root': str(root), 'stage': str(stage), 'revisions': {},
              'driverSha256': digest(Path(__file__)), 'cases': CASES,
              'pairOrders': PAIR_ORDERS}
    (output / 'starting-git-status.txt').write_text(subprocess.check_output(
        ['git', 'status', '--short'], cwd=root, text=True))
    for label in ['published', 'current']:
        destination = stage / label
        destination.mkdir()
        shutil.copytree(root / 'benchmarks', destination / 'benchmarks',
                        ignore=shutil.ignore_patterns('build', '.dart_tool', 'Pods',
                                                     'ephemeral', '.symlinks'))
        for name, relative in package_paths.items():
            target = destination / relative
            target.mkdir(parents=True)
            if label == 'published':
                archive = archives / f'{name}-{registry[name]["version"]}.tar.gz'
                with tarfile.open(fileobj=io.BytesIO(archive.read_bytes()), mode='r:gz') as package:
                    package.extractall(target, filter='data')
            else:
                shutil.copytree(root / relative / 'lib', target / 'lib')
                for filename in ['pubspec.yaml', 'README.md', 'LICENSE']:
                    if (root / relative / filename).exists():
                        shutil.copy2(root / relative / filename, target / filename)
        # Await either void or Future<void> close APIs; this is teardown only.
        patches = []
        for path in sorted((destination / 'benchmarks/lib/benchmarks').rglob('*.dart')):
            old = path.read_text()
            new = re.sub(r'await ([\w.]+)\.close\(\);',
                         r'await Future<void>.sync(\1.close);', old)
            if old != new:
                path.write_text(new)
                patches.extend(difflib.unified_diff(old.splitlines(True), new.splitlines(True),
                    fromfile=str(path.relative_to(destination)), tofile=str(path.relative_to(destination))))
        if label == 'published':
            path = destination / 'benchmarks/lib/ui/dashboard_page.dart'
            old = path.read_text()
            if old.count('ref.own(') != 1:
                raise RuntimeError('Unexpected dashboard ownership registration')
            new = old.replace('ref.own(', 'ref.autoDispose(')
            path.write_text(new)
            patches.extend(difflib.unified_diff(old.splitlines(True), new.splitlines(True),
                fromfile=str(path.relative_to(destination)), tofile=str(path.relative_to(destination))))
        (output / f'{label}-compatibility.patch').write_text(''.join(patches))
        print(f'Resolving {label}', flush=True)
        with (output / f'{label}-pub-get.log').open('w') as log:
            subprocess.run([flutter, 'pub', 'get'], cwd=destination / 'benchmarks',
                           stdout=log, stderr=subprocess.STDOUT, check=True, timeout=180)
        files = manifest(destination)
        source_digest = hashlib.sha256(json.dumps(files, sort_keys=True).encode()).hexdigest()
        revision = {'root': str(destination), 'digest': source_digest, 'files': files}
        inputs['revisions'][label] = revision
        write_json(output / 'inputs.json', inputs)
        print(f'Building {label}: {source_digest}', flush=True)
        with (output / f'{label}-build.log').open('w') as log:
            subprocess.run([flutter, 'build', 'macos', '--release',
                            '--target=lib/compare_published_release.dart',
                            f'--dart-define=BENCHMARK_REVISION={source_digest}'],
                           cwd=destination / 'benchmarks', stdout=log, stderr=subprocess.STDOUT,
                           check=True, timeout=600)
        binary = destination / 'benchmarks/build/macos/Build/Products/Release/benchmarks.app/Contents/MacOS/benchmarks'
        aot = binary.parent.parent / 'Frameworks/App.framework/App'
        revision.update(binary=str(binary), binarySha256=digest(binary), dartAotSha256=digest(aot))
        shutil.copy2(destination / 'benchmarks/pubspec.lock', output / f'{label}-pubspec.lock')
    # Check the actual workload files are identical, not just their names/config.
    first = Path(inputs['revisions']['published']['root'])
    second = Path(inputs['revisions']['current']['root'])
    for path in (first / 'benchmarks/lib').rglob('*.dart'):
        relative = path.relative_to(first)
        if relative.as_posix() != 'benchmarks/lib/ui/dashboard_page.dart':
            if digest(path) != digest(second / relative):
                raise RuntimeError(f'Harness differs between revisions: {relative}')
    def lock_entries(path):
        return {m[1]: m[2] for m in re.finditer(
            r'^  (\w+):\n(.*?)(?=^  \w+:\n|^sdks:|\Z)', path.read_text(), re.M | re.S)
            if not m[1].startswith('levit')}
    if lock_entries(output / 'published-pubspec.lock') != lock_entries(output / 'current-pubspec.lock'):
        raise RuntimeError('Non-Levit dependency resolutions differ')
    write_json(output / 'prepared.json', inputs)
    return inputs


def summarize(records):
    summaries = []
    for name, mode in CASES:
        selected = [r for r in records if r['workload'] == name and r['dependencyMode'] == mode]
        entry = {'workload': name, 'dependencyMode': mode, 'valid': all(r['valid'] for r in selected)}
        if not entry['valid']:
            entry['errors'] = [r['name'] for r in selected if not r['valid']]
            summaries.append(entry)
            continue
        for metric in ['wallP50', 'wallP95', 'buildP50', 'buildP95', 'rasterP50', 'rasterP95']:
            def value(record):
                result = record['report']['results'][0]
                if metric.startswith('wall'):
                    samples = result['samplesMicros']
                else:
                    key = 'buildUs' if metric.startswith('build') else 'rasterUs'
                    samples = [f[key] for f in result['frameTimings']]
                if not samples:
                    return None
                return (statistics.median(samples) if metric.endswith('P50')
                        else sorted(samples)[math.ceil(len(samples) * .95) - 1])
            values = [value(r) for r in selected]
            if any(v is None for v in values):
                continue
            by_label = {label: [v for v, r in zip(values, selected) if r['revision'] == label]
                        for label in ['published', 'current']}
            medians = {label: statistics.median(v) for label, v in by_label.items()}
            pairs = []
            for i in range(0, len(selected), 2):
                p = {selected[j]['revision']: values[j] for j in (i, i + 1)}
                pairs.append((p['current'] / p['published'] - 1) * 100)
            entry[metric] = {'publishedUs': medians['published'], 'currentUs': medians['current'],
                             'changePercent': (medians['current'] / medians['published'] - 1) * 100,
                             'pairedPercent': pairs, 'runsUs': by_label}
        summaries.append(entry)
    return summaries


def measure(output, inputs):
    run_dir = output / 'runs'
    if run_dir.exists():
        raise RuntimeError('Run directory exists; use new evidence to preserve completed/partial runs.')
    for revision in inputs['revisions'].values():
        root = Path(revision['root'])
        changed = [p for p, sha in revision['files'].items() if digest(root / p) != sha]
        if changed:
            raise RuntimeError(f'Prepared input changed: {changed}')
        binary = Path(revision['binary'])
        if (digest(binary) != revision['binarySha256'] or
                digest(binary.parent.parent / 'Frameworks/App.framework/App') != revision['dartAotSha256']):
            raise RuntimeError('Prepared binary changed')
    run_dir.mkdir()
    records = []
    environment_reference = None
    for case_index, (workload, mode) in enumerate(CASES, 1):
        for pair_index, order in enumerate(PAIR_ORDERS, 1):
            for label in order:
                name = f'{case_index:02}-{mode}-pair{pair_index}-{label}'
                print(f'Running {name}: {workload}', flush=True)
                revision = inputs['revisions'][label]
                env = dict(os.environ, LEVIT_PERFORMANCE_RUN='1', LEVIT_DIAGNOSTICS='off',
                           LEVIT_COMPARISON_WORKLOAD=workload, LEVIT_COMPARISON_MODE=mode)
                started = time.time()
                log_path = run_dir / f'{name}.log'
                with log_path.open('w') as log:
                    process = subprocess.run([revision['binary']], env=env, stdout=log,
                                             stderr=subprocess.STDOUT, timeout=180)
                payloads = [line.split('PUBLISHED_COMPARISON_JSON:', 1)[1]
                            for line in log_path.read_text().splitlines()
                            if 'PUBLISHED_COMPARISON_JSON:' in line]
                if len(payloads) != 1:
                    raise RuntimeError(f'Missing result in {name}; exit={process.returncode}')
                report = json.loads(payloads[0])
                write_json(run_dir / f'{name}.json', report)
                environment = report['environment']
                comparable = {k: v for k, v in environment.items()
                              if k not in ['capturedAt', 'sourceRevision', 'benchmarks']}
                if environment_reference is None:
                    environment_reference = comparable
                if comparable != environment_reference:
                    raise RuntimeError('Device/build/viewport metadata changed')
                if (environment['sourceRevision'] != revision['digest'] or
                        environment['iterations'] != 50 or environment['warmupIterations'] != 5 or
                        environment['buildMode'] != 'release' or environment['benchmarkProfile'] != 'production' or
                        report['methodologyVersion'] != 2 or report['dependencyMode'] != mode or
                        len(report['results']) != 1 or environment['benchmarks'] != [workload]):
                    raise RuntimeError('Unexpected source identity, methodology or workload')
                result = report['results'][0]
                expected_frames = 50 if workload.endswith('(UI)') else 0
                valid = (process.returncode == 0 and result['success'] and result['error'] is None and
                         len(result['samplesMicros']) == 50 and len(result['frameTimings']) == expected_frames and
                         result['benchmark'] == workload and result['framework'] == 'levit')
                records.append({'name': name, 'revision': label, 'workload': workload, 'dependencyMode': mode,
                                'valid': valid, 'seconds': time.time() - started, 'report': report})
                write_json(output / 'run-status.json', [{k: v for k, v in r.items() if k != 'report'} for r in records])
                print(f'{"PASS" if valid else "INVALID"}: {name}', flush=True)
    write_json(output / 'summary.json', summarize(records))
    print(f'Complete: {sum(r["valid"] for r in records)}/{len(records)} valid cases.', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument('--output', type=Path, required=True,
                        help='Directory containing verified published-packages.json from pub.dev API')
    parser.add_argument('--flutter', required=True)
    phases = parser.add_mutually_exclusive_group()
    phases.add_argument('--prepare-only', action='store_true')
    phases.add_argument('--measure-only', action='store_true')
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    inputs = (json.loads((output / 'prepared.json').read_text()) if args.measure_only
              else prepare(args.root.resolve(), output, args.flutter))
    if not args.prepare_only:
        measure(output, inputs)


if __name__ == '__main__':
    main()
