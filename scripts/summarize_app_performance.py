#!/usr/bin/env python3
"""Summarize all cases without treating consecutive samples as independent runs."""
import argparse
import json
import math
from pathlib import Path
from statistics import median


def summarize(directory):
    order = ['01-before', '02-after', '03-after', '04-before']
    reports = {name: json.loads((directory / f'{name}.json').read_text()) for name in order}
    rows = []
    for result in reports[order[0]]['results']:
        benchmark, framework = result['benchmark'], result['framework']
        results = [next(r for r in reports[name]['results']
                        if r['benchmark'] == benchmark and r['framework'] == framework)
                   for name in order]
        assert all(r['success'] and len(r['samplesMicros']) == 50 for r in results)
        metrics = ['wallUs'] + (['buildUs', 'rasterUs'] if result['frameTimings'] else [])
        for metric in metrics:
            values = [r['samplesMicros'] if metric == 'wallUs' else
                      [frame[metric] for frame in r['frameTimings']] for r in results]
            medians = [median(xs) for xs in values]
            p95 = [sorted(xs)[math.ceil(len(xs) * .95) - 1] for xs in values]
            before = median([medians[0], medians[3]])
            after = median([medians[1], medians[2]])
            rows.append({'benchmark': benchmark, 'framework': framework, 'metric': metric,
                         'runP50': dict(zip(order, medians)), 'runP95': dict(zip(order, p95)),
                         'beforeMedianOfRunMedians': before, 'afterMedianOfRunMedians': after,
                         'changePercent': 100 * (after / before - 1) if before else None,
                         'pairedChangePercent': [100 * (medians[1] / medians[0] - 1),
                                                 100 * (medians[2] / medians[3] - 1)]})
    summary = {'order': order, 'note': 'Two independent processes per revision; raw within-run samples are not independent trials.',
               'cases': sum(len(d['results']) for d in reports.values()),
               'samples': sum(len(r['samplesMicros']) for d in reports.values() for r in d['results']),
               'frames': sum(len(r['frameTimings']) for d in reports.values() for r in d['results']),
               'rows': rows}
    (directory / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    lines = ['# Repeated dashboard comparison', '', summary['note'], '',
             'Negative change means lower elapsed time. All values are microseconds.', '',
             '| Benchmark | Framework | Metric | Before 1 p50 | After 1 p50 | After 2 p50 | Before 2 p50 | Paired changes |',
             '|---|---|---|---:|---:|---:|---:|---|']
    for row in rows:
        medians = ' | '.join(f'{x:g}' for x in row['runP50'].values())
        changes = ', '.join(f'{x:+.1f}%' for x in row['pairedChangePercent'])
        lines.append(f'| {row["benchmark"]} | {row["framework"]} | {row["metric"]} | {medians} | {changes} |')
    (directory / 'summary.md').write_text('\n'.join(lines) + '\n')
    print(f'{directory}: {summary["cases"]} cases, {summary["samples"]} samples, {summary["frames"]} frames')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    summarize(parser.parse_args().directory)
