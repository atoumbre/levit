import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'src/benchmark_support.dart';

const appRunOrder = ['01-before', '02-after', '03-after', '04-before'];

JsonMap summarizeAppReports(Map<String, JsonMap> reports) {
  final rows = <JsonMap>[];
  for (final result in reports[appRunOrder.first]!['results'] as List) {
    final benchmark = result['benchmark'];
    final framework = result['framework'];
    final results = [
      for (final name in appRunOrder)
        (reports[name]!['results'] as List).singleWhere(
          (result) =>
              result['benchmark'] == benchmark &&
              result['framework'] == framework,
        ),
    ];
    requireCondition(
      results.every(
        (result) =>
            result['success'] == true &&
            (result['samplesMicros'] as List).length == 50,
      ),
      'Expected successful results with 50 samples for $benchmark/$framework',
    );
    final metrics = [
      'wallUs',
      if ((result['frameTimings'] as List).isNotEmpty) ...[
        'buildUs',
        'rasterUs',
      ],
    ];
    for (final metric in metrics) {
      final values = [
        for (final result in results)
          metric == 'wallUs'
              ? result['samplesMicros'] as List
              : [for (final frame in result['frameTimings']) frame[metric]],
      ];
      final medians = values.map(median).toList();
      final before = median([medians[0], medians[3]]);
      final after = median([medians[1], medians[2]]);
      rows.add({
        'benchmark': benchmark,
        'framework': framework,
        'metric': metric,
        'runP50': Map.fromIterables(appRunOrder, medians),
        'runP95': Map.fromIterables(appRunOrder, values.map(percentile95)),
        'beforeMedianOfRunMedians': before,
        'afterMedianOfRunMedians': after,
        'changePercent': percentChange(before, after),
        'pairedChangePercent': [
          percentChange(medians[0], medians[1]),
          percentChange(medians[3], medians[2]),
        ],
      });
    }
  }
  final allResults = [
    for (final report in reports.values) ...report['results'] as List,
  ];
  return {
    'order': appRunOrder,
    'note':
        'Each revision runs in two independent processes. Summaries compare per-process medians.',
    'cases': allResults.length,
    'samples': allResults.fold<int>(
      0,
      (sum, result) => sum + (result['samplesMicros'] as List).length,
    ),
    'frames': allResults.fold<int>(
      0,
      (sum, result) => sum + (result['frameTimings'] as List).length,
    ),
    'rows': rows,
  };
}

void main(List<String> arguments) {
  final args = parseOptions(
    arguments,
    ArgParser(),
    'Usage: dart run scripts/summarize_app_performance.dart DIRECTORY',
  );
  if (args == null) return;
  requireCondition(args.rest.length == 1, 'Supply one comparison directory');
  final directory = args.rest.single;
  final reports = {
    for (final name in appRunOrder)
      name: readJson(p.join(directory, '$name.json')),
  };
  final summary = summarizeAppReports(reports);
  writeJson(p.join(directory, 'summary.json'), summary);
  final lines = [
    '# Repeated dashboard comparison',
    '',
    summary['note'],
    '',
    'Negative change means lower elapsed time. All values are microseconds.',
    '',
    '| Benchmark | Framework | Metric | Before 1 p50 | After 1 p50 | After 2 p50 | Before 2 p50 | Paired changes |',
    '|---|---|---|---:|---:|---:|---:|---|',
  ];
  for (final row in summary['rows']) {
    final medians = (row['runP50'] as Map).values.join(' | ');
    final changes = (row['pairedChangePercent'] as List)
        .map(
          (change) => change == null
              ? 'n/a'
              : '${change >= 0 ? '+' : ''}${(change as num).toStringAsFixed(1)}%',
        )
        .join(', ');
    lines.add(
      '| ${row['benchmark']} | ${row['framework']} | ${row['metric']} | $medians | $changes |',
    );
  }
  File(
    p.join(directory, 'summary.md'),
  ).writeAsStringSync('${lines.join('\n')}\n');
  print(
    '$directory: ${summary['cases']} cases, ${summary['samples']} samples, ${summary['frames']} frames',
  );
}
