from pathlib import Path
import json
import math
import statistics

root = Path('/Users/atoumbre/SoftiLab/levit-svg/reports/validation/0.1.0/recertification/final')
runs = [json.loads((root / f'performance-{label}-{mode}-{diagnostics}-{repeat}.json').read_text())
        for mode in ['profile', 'release'] for label in ['reference', 'before', 'candidate']
        for diagnostics in ['off', 'on'] for repeat in [1, 2]]
summary = json.loads((root / 'performance-summary.json').read_text())
assert len(runs) == 24 and len(summary) == 20

def percentile(values, q):
    return sorted(values)[math.ceil(len(values) * q) - 1]

frames = []
for mode in ['profile', 'release']:
    for enabled in [False, True]:
        for label in ['reference', 'before', 'candidate']:
            rows = [row for run in runs if run['mode'] == mode and run['label'] == label
                    for row in run['measurements'] if row['diagnostics'] == enabled
                    and row['workload'] == 'list_1000_frame']
            timings = [sample for row in rows for sample in row['frameTimings']]
            assert len(timings) == 360
            frames.append({'mode': mode, 'diagnostics': enabled, 'label': label,
                           'frames': len(timings),
                           'buildMedianUs': statistics.median(x['buildUs'] for x in timings),
                           'buildP95Us': percentile([x['buildUs'] for x in timings], .95),
                           'rasterMedianUs': statistics.median(x['rasterUs'] for x in timings),
                           'rasterP95Us': percentile([x['rasterUs'] for x in timings], .95),
                           'buildRoundMediansUs': [statistics.median(x['buildUs'] for x in row['frameTimings']) for row in rows]})

events = []
for label in ['reference', 'before', 'candidate']:
    for workload in dict.fromkeys(row['workload'] for row in runs[0]['measurements']):
        rows = [row for run in runs if run['label'] == label
                for row in run['measurements'] if row['diagnostics'] and row['workload'] == workload]
        counts = {row['deliveredEvents'] / (len(row['samplesUs']) + row['warmups']) for row in rows}
        events.append({'label': label, 'workload': workload, 'eventsPerIteration': sorted(counts)})

result = {'nativeProcesses': len(runs), 'timedSamples': sum(len(r['samplesUs']) for run in runs for r in run['measurements']),
          'matchedFrames': sum(row['frames'] for row in frames), 'frameSummary': frames,
          'eventCounts': events, 'candidateRssRangeMiB': [
              fn(row['rssBytes'] / 1024**2 for run in runs if run['label'] == 'candidate' for row in run['measurements'])
              for fn in [min, max]]}
(root / 'performance-analysis.json').write_text(json.dumps(result, indent=2) + '\n')

tables = []
labels = {'notify_10000': '10,000 observed writes', 'fanout_128_x_100': '128 computed consumers × 100 writes',
          'scope_lifetime_100': '100 scope lifetimes', 'tasks_100': '100 leaf tasks', 'list_1000_frame': 'Virtualized 1,000-row list: frame wall time'}
for mode in ['profile', 'release']:
    tables += [f'### {mode.title()} workload latency', '',
               '| Diagnostics | Workload | Reference ms | Before fixes ms | Candidate ms | vs reference | vs before |',
               '| --- | --- | ---: | ---: | ---: | ---: | ---: |']
    for row in summary:
        if row['mode'] != mode: continue
        tables.append(f"| {'On' if row['diagnostics'] else 'Off'} | {labels[row['workload']]} | {row['referenceUs']/1000:.3f} | {row['beforeOptimizationUs']/1000:.3f} | {row['candidateUs']/1000:.3f} | {row['changePercent']:+.1f}% | {row['optimizationChangePercent']:+.1f}% |")
    tables.append('')
tables += ['### Flutter engine timings', '',
           'Pooled medians / nearest-rank p95, milliseconds; 360 matched frames per row.', '',
           '| Mode | Diagnostics | Revision | Build median / p95 | Raster median / p95 |',
           '| --- | --- | --- | ---: | ---: |']
for row in frames:
    tables.append(f"| {row['mode']} | {'On' if row['diagnostics'] else 'Off'} | {row['label']} | {row['buildMedianUs']/1000:.3f} / {row['buildP95Us']/1000:.3f} | {row['rasterMedianUs']/1000:.3f} / {row['rasterP95Us']/1000:.3f} |")
(root / 'performance-tables.md').write_text('\n'.join(tables) + '\n')
print('\n'.join(tables))
print(json.dumps({'eventCounts': events, 'frames': frames, 'rss': result['candidateRssRangeMiB']}, indent=2))
