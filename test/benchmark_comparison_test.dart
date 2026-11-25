import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../scripts/compare_computed_modes.dart';
import '../scripts/compare_release_performance.dart';
import '../scripts/src/benchmark_support.dart';
import '../scripts/summarize_app_performance.dart';

void main() {
  test(
    'sample statistics handle even populations and nearest-rank percentiles',
    () {
      expect(median([30, 10, 20, 40]), 25);
      expect(percentile95(List.generate(50, (index) => index + 1)), 48);
      expect(percentChange(0, 1), isNull);
      expect(() => median([]), throwsStateError);
    },
  );

  test('dashboard summaries retain independent process and paired medians', () {
    final samples = [10, 5, 15, 20];
    final reports = {
      for (var index = 0; index < appRunOrder.length; index++)
        appRunOrder[index]: <String, dynamic>{
          'results': [_result(samples[index])],
        },
    };
    final summary = summarizeAppReports(reports);
    final row = (summary['rows'] as List).single;
    expect(summary['samples'], 200);
    expect(summary['cases'], 4);
    expect(row['beforeMedianOfRunMedians'], 15);
    expect(row['afterMedianOfRunMedians'], 10);
    expect(row['pairedChangePercent'], [-50, -25]);
  });

  test('computed summaries pair reversed orders and isolated workloads', () {
    final reports = [
      for (final name in ['first', 'second'])
        for (final (mode, order) in computedSchedule)
          <String, dynamic>{
            'dependencyMode': mode,
            'workloadOrder': order,
            'results': [_result(mode == 'static' ? 5 : 10, name: name)],
          },
    ];
    final summary = summarizeComputedReports(reports);
    expect(summary.keys, ['first', 'second']);
    for (final metrics in summary.values) {
      expect(metrics['p50']['pairedPercent'], List.filled(4, -50));
      expect(metrics['p95']['dynamicRunsUs'], List.filled(4, 10));
    }
    expect(
      () => summarizeComputedReports(reports.sublist(1)),
      throwsStateError,
    );
  });

  test(
    'computed reports reject missing samples and mismatched source identities',
    () {
      final report = <String, dynamic>{
        'environment': {
          'sourceRevision': 'revision',
          'buildMode': 'release',
          'benchmarkProfile': 'production',
          'iterations': 50,
          'warmupIterations': 5,
          'benchmarks': computedWorkloads,
        },
        'methodologyVersion': 2,
        'dependencyMode': 'dynamic',
        'workloadOrder': 'forward',
        'workloadSelection': null,
        'workloadConfig': computedWorkloadConfig,
        'results': [
          for (final name in computedWorkloads) _result(10, name: name),
        ],
      };
      void validate() => validateComputedReport(
        report,
        sourceDigest: 'revision',
        buildMode: 'release',
        dependencyMode: 'dynamic',
        workloadOrder: 'forward',
      );
      expect(validate, returnsNormally);
      report['environment']['sourceRevision'] = 'different';
      expect(validate, throwsStateError);
      report['environment']['sourceRevision'] = 'revision';
      report['results'][0]['samplesMicros'] = [10];
      expect(validate, throwsStateError);
    },
  );

  test(
    'release summaries preserve round medians, body times, and display checks',
    () {
      final runs = <JsonMap>[
        for (final mode in ['profile', 'release'])
          for (final enabled in [false, true])
            for (final label in ['reference', 'candidate'])
              for (var repeat = 0; repeat < 2; repeat++)
                _releaseReport(mode, enabled, label),
      ];
      final summary = summarizeReleaseReports(runs, ['reference', 'candidate']);
      expect(summary, hasLength(20));
      expect(summary.first['changePercent'], closeTo(-20, .0001));
      expect(summary.first['roundMediansUs']['reference'], List.filled(6, 10));
      expect(summary.first['bodyChangePercent'], closeTo(-20, .0001));
      runs.last['refreshRate'] = 60;
      expect(
        () => summarizeReleaseReports(runs, ['reference', 'candidate']),
        throwsStateError,
      );
    },
  );

  test(
    'release validation rejects incomplete diagnostics teardown and frame data',
    () {
      final report = _releaseReport('release', false, 'candidate');
      void validate() =>
          validateReleaseReport(report, 'release', 'off', 'candidate');
      expect(validate, returnsNormally);
      report['middlewareDetached'] = false;
      expect(validate, throwsStateError);
      report['middlewareDetached'] = true;
      report['measurements'][4]['frameTimings'] = [];
      expect(validate, throwsStateError);
    },
  );

  test('report extraction requires exactly one completed payload', () {
    expect(extractReport('log\nRESULT:{"ok":true}\n', 'RESULT:'), {'ok': true});
    expect(() => extractReport('log', 'RESULT:'), throwsStateError);
    expect(
      () => extractReport('RESULT:{}\nRESULT:{}', 'RESULT:'),
      throwsStateError,
    );
  });

  test(
    'source manifests include libraries and locks while excluding build outputs',
    () {
      final root = Directory.systemTemp.createTempSync('levit_manifest_');
      addTearDown(() => root.deleteSync(recursive: true));
      for (final path in [
        'packages/demo/lib/main.dart',
        'packages/demo/pubspec.lock',
        'packages/demo/build/lib/generated.dart',
        'benchmarks/test/widget_test.dart',
      ]) {
        final file = File(p.join(root.path, path));
        file.parent.createSync(recursive: true);
        file.writeAsStringSync('fixture');
      }
      final manifest = sourceManifest(root.path);
      expect(manifest.keys, [
        'packages/demo/lib/main.dart',
        'packages/demo/pubspec.lock',
      ]);
      expect(
        manifestDigest(manifest),
        manifestDigest(Map.fromEntries(manifest.entries.toList().reversed)),
      );
    },
  );

  test(
    'logged commands retain diagnostics before reporting process failures',
    () async {
      final root = Directory.systemTemp.createTempSync('levit_process_');
      addTearDown(() => root.deleteSync(recursive: true));
      final probe = File(p.join(root.path, 'probe.dart'));
      probe.writeAsStringSync(
        "import 'dart:io'; void main() { print(Platform.environment['LEVIT_PROBE']); stderr.writeln('failed'); exit(7); }",
      );
      final log = p.join(root.path, 'probe.log');
      await expectLater(
        runLogged(
          [Platform.resolvedExecutable, probe.path],
          log,
          workingDirectory: root.path,
          environment: {'LEVIT_PROBE': 'injected'},
        ),
        throwsStateError,
      );
      expect(File(log).readAsStringSync(), 'injected\nfailed\n');
    },
  );
}

JsonMap _result(int value, {String name = 'workload'}) => {
  'benchmark': name,
  'framework': 'levit',
  'implementation': 'Levit (dynamic)',
  'success': true,
  'error': null,
  'samplesMicros': List.filled(50, value),
  'warmupIterations': 5,
  'frameTimings': <dynamic>[],
};

JsonMap _releaseReport(String mode, bool enabled, String label) {
  final duration = label == 'candidate' ? 8 : 10;
  return {
    'mode': mode,
    'reference': label,
    'label': label,
    'activityGuard': true,
    'diagnosticsMode': enabled ? 'on' : 'off',
    'middlewareDetached': true,
    'physicalSize': [1600, 1200],
    'pixelRatio': 2,
    'displayId': 1,
    'refreshRate': 120,
    'measurements': [
      for (var round = 0; round < 3; round++)
        for (final name in ['notify', 'fanout', 'scope', 'tasks', 'list_frame'])
          {
            'workload': name,
            'diagnostics': enabled,
            'samplesUs': List.filled(
              name.contains('frame') ? 60 : 30,
              duration,
            ),
            'bodySamplesUs': List.filled(30, duration / 2),
            'warmups': 5,
            'minimumWarmupUs': 500000,
            'warmupElapsedUs': 500000,
            'frameTimings': name.contains('frame')
                ? List.filled(60, {'buildUs': 1, 'rasterUs': 1})
                : <dynamic>[],
          },
    ],
  };
}
