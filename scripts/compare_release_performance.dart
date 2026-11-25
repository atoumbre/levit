import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'src/benchmark_support.dart';

void validateReleaseReport(
  JsonMap report,
  String mode,
  String diagnostics,
  String reference,
) {
  requireCondition(
    report['mode'] == mode &&
        report['reference'] == reference &&
        report['activityGuard'] == true &&
        report['diagnosticsMode'] == diagnostics &&
        report['middlewareDetached'] == true,
    'Unexpected native run identity or lifecycle state',
  );
  final measurements = report['measurements'] as List;
  requireCondition(measurements.length == 15, 'Expected 15 measurement rounds');
  for (final row in measurements) {
    final frames = (row['workload'] as String).contains('frame');
    final samples = row['samplesUs'] as List;
    requireCondition(
      row['diagnostics'] == (diagnostics == 'on') &&
          samples.length == (frames ? 60 : 30) &&
          samples.every((sample) => sample > 0),
      'Invalid samples for ${row['workload']}',
    );
    if (frames) {
      requireCondition(
        (row['frameTimings'] as List).length == 60,
        'Expected 60 frame timings',
      );
    } else {
      final bodies = row['bodySamplesUs'] as List;
      requireCondition(
        row['warmups'] >= 5 &&
            row['minimumWarmupUs'] == 500000 &&
            row['warmupElapsedUs'] >= row['minimumWarmupUs'] &&
            bodies.length == 30,
        'Incomplete warmup or body samples for ${row['workload']}',
      );
      for (var index = 0; index < samples.length; index++) {
        requireCondition(
          bodies[index] > 0 && bodies[index] <= samples[index],
          'Body time exceeds total time for ${row['workload']}',
        );
      }
    }
  }
}

List<JsonMap> summarizeReleaseReports(List<JsonMap> runs, List<String> labels) {
  final layouts = [
    for (final run in runs)
      [
        run['physicalSize'],
        run['pixelRatio'],
        run['displayId'],
        run['refreshRate'],
      ],
  ];
  requireCondition(
    layouts.isNotEmpty &&
        layouts.every((layout) => sameJson(layout, layouts.first)),
    'Inconsistent display geometry',
  );
  final workloads = {
    for (final row in runs.first['measurements']) row['workload'] as String,
  };
  final summary = <JsonMap>[];
  for (final mode in ['profile', 'release']) {
    for (final enabled in [false, true]) {
      for (final workload in workloads) {
        final rowsByLabel = {
          for (final label in labels)
            label: [
              for (final run in runs)
                if (run['mode'] == mode && run['label'] == label)
                  for (final row in run['measurements'])
                    if (row['workload'] == workload &&
                        row['diagnostics'] == enabled)
                      row as JsonMap,
            ],
        };
        final medians = {
          for (final entry in rowsByLabel.entries)
            entry.key: [
              for (final row in entry.value) median(row['samplesUs']),
            ],
        };
        final before = median(medians['reference']!);
        final after = median(medians['candidate']!);
        final entry = <String, dynamic>{
          'mode': mode,
          'diagnostics': enabled,
          'workload': workload,
          'roundMediansUs': medians,
          'referenceUs': before,
          'candidateUs': after,
          'changePercent': percentChange(before, after),
        };
        if (!workload.contains('frame')) {
          final bodyMedians = {
            for (final item in rowsByLabel.entries)
              item.key: [
                for (final row in item.value) median(row['bodySamplesUs']),
              ],
          };
          final waitMedians = {
            for (final item in rowsByLabel.entries)
              item.key: [
                for (final row in item.value)
                  median([
                    for (
                      var index = 0;
                      index < (row['samplesUs'] as List).length;
                      index++
                    )
                      row['samplesUs'][index] - row['bodySamplesUs'][index],
                  ]),
              ],
          };
          final bodyBefore = median(bodyMedians['reference']!);
          final bodyAfter = median(bodyMedians['candidate']!);
          entry.addAll({
            'roundBodyMediansUs': bodyMedians,
            'roundEventLoopWaitMediansUs': waitMedians,
            'bodyReferenceUs': bodyBefore,
            'bodyCandidateUs': bodyAfter,
            'bodyChangePercent': percentChange(bodyBefore, bodyAfter),
          });
        }
        if (labels.contains('before')) {
          final previous = median(medians['before']!);
          entry.addAll({
            'beforeOptimizationUs': previous,
            'optimizationChangePercent': percentChange(previous, after),
          });
        }
        summary.add(entry);
      }
    }
  }
  return summary;
}

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('reference-label', defaultsTo: '539f130');
  final args = parseOptions(
    arguments,
    parser,
    'Usage: dart run scripts/compare_release_performance.dart REFERENCE_ROOT OUTPUT [BEFORE_ROOT]\n'
    'Build each checkout in profile and release using lib/release_performance.dart first.',
  );
  if (args == null) return;
  requireCondition(
    args.rest.length == 2 || args.rest.length == 3,
    'Supply REFERENCE_ROOT OUTPUT and optionally BEFORE_ROOT',
  );
  final roots = {
    'reference': Directory(args.rest[0]).resolveSymbolicLinksSync(),
    'candidate': p.dirname(p.dirname(Platform.script.toFilePath())),
    if (args.rest.length == 3)
      'before': Directory(args.rest[2]).resolveSymbolicLinksSync(),
  };
  final output = p.absolute(args.rest[1]);
  Directory(output).createSync(recursive: true);
  for (final root in roots.values) {
    for (final mode in ['profile', 'release']) {
      requireCondition(
        File(appBinary(root, mode)).existsSync(),
        'Build the $mode executable first: $root',
      );
    }
  }
  final runs = <JsonMap>[];
  for (var repeat = 0; repeat < 2; repeat++) {
    final forwardLabels = [
      'reference',
      if (roots.containsKey('before')) 'before',
      'candidate',
    ];
    final labels = repeat == 0
        ? forwardLabels
        : forwardLabels.reversed.toList();
    for (final mode in ['profile', 'release']) {
      for (final diagnostics in repeat == 0 ? ['off', 'on'] : ['on', 'off']) {
        for (final label in labels) {
          final binary = appBinary(roots[label]!, mode);
          final name = 'performance-$label-$mode-$diagnostics-${repeat + 1}';
          print('Measuring $name');
          final result = await runLogged(
            [binary],
            p.join(output, '$name.log'),
            workingDirectory: Directory.current.path,
            timeout: const Duration(minutes: 5),
            environment: {
              ...Platform.environment,
              'LEVIT_PERFORMANCE_RUN': '1',
              'LEVIT_DIAGNOSTICS': diagnostics,
            },
          );
          requireCondition(
            result.stderr.contains('LEVIT_PERFORMANCE_ACTIVITY_ACTIVE'),
            'Missing macOS activity marker',
          );
          final report = extractReport(
            result.stdout,
            'LEVIT_PERFORMANCE_JSON:',
          );
          validateReleaseReport(
            report,
            mode,
            diagnostics,
            label == 'reference' ? args.option('reference-label')! : label,
          );
          report.addAll({
            'repeat': repeat + 1,
            'label': label,
            'executableSha256': fileDigest(binary),
            'aotSha256': fileDigest(appAot(binary)),
          });
          writeJson(p.join(output, '$name.json'), report);
          runs.add(report);
          print('Passed $name');
        }
      }
    }
  }
  writeJson(
    p.join(output, 'performance-summary.json'),
    summarizeReleaseReports(runs, roots.keys.toList()),
  );
  print('All ${runs.length} isolated native measurement runs passed.');
}
