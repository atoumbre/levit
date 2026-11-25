import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'src/benchmark_support.dart';

const computedSchedule = [
  ('dynamic', 'forward'),
  ('static', 'forward'),
  ('static', 'reverse'),
  ('dynamic', 'reverse'),
  ('static', 'forward'),
  ('dynamic', 'forward'),
  ('dynamic', 'reverse'),
  ('static', 'reverse'),
];
const computedWorkloadConfig = {
  'diamondUpdates': 10000,
  'fanOutDependents': 1000,
  'fanInInputs': 1000,
  'asyncUpdates': 100,
  'batchUpdates': 1000,
  'chainDepth': 1000,
  'chainUpdates': 1000,
};
const computedWorkloads = [
  'Diamond Graph (Observed Updates)',
  'Fan Out Update',
  'Fan In Update',
  'Async Computed',
  'Batch vs Un-batched',
  'Computed Chain (Deep Propagation)',
];

JsonMap summarizeComputedReports(List<JsonMap> reports) {
  final resultSets = [
    for (final report in reports)
      {
        for (final result in report['results'])
          result['benchmark'] as String: result as JsonMap,
      },
  ];
  final names = {for (final results in resultSets) ...results.keys};
  final summary = <String, dynamic>{};
  for (final name in names) {
    final selected = [
      for (var index = 0; index < reports.length; index++)
        if (resultSets[index].containsKey(name))
          (reports[index], resultSets[index][name]!),
    ];
    final metrics = <String, dynamic>{};
    for (final metric in ['p50', 'p95']) {
      final values = [
        for (final (_, result) in selected)
          metric == 'p50'
              ? median(result['samplesMicros'])
              : percentile95(result['samplesMicros']),
      ];
      final dynamicValues = <num>[];
      final staticValues = <num>[];
      for (var index = 0; index < selected.length; index++) {
        final mode = selected[index].$1['dependencyMode'];
        if (mode == 'dynamic') dynamicValues.add(values[index]);
        if (mode == 'static') staticValues.add(values[index]);
      }
      requireCondition(selected.length.isEven, 'Incomplete pairs for $name');
      final paired = <double?>[];
      for (var index = 0; index < selected.length; index += 2) {
        final pair = {
          selected[index].$1['dependencyMode']: values[index],
          selected[index + 1].$1['dependencyMode']: values[index + 1],
        };
        requireCondition(
          pair.containsKey('static') && pair.containsKey('dynamic'),
          'Unbalanced modes for $name',
        );
        paired.add(percentChange(pair['dynamic']!, pair['static']!));
      }
      final dynamicMedian = median(dynamicValues);
      final staticMedian = median(staticValues);
      metrics[metric] = {
        'dynamicRunsUs': dynamicValues,
        'staticRunsUs': staticValues,
        'dynamicUs': dynamicMedian,
        'staticUs': staticMedian,
        'staticVsDynamicPercent': percentChange(dynamicMedian, staticMedian),
        'pairedPercent': paired,
      };
    }
    summary[name] = metrics;
  }
  return summary;
}

void validateComputedReport(
  JsonMap report, {
  required String sourceDigest,
  required String buildMode,
  required String dependencyMode,
  required String workloadOrder,
  String? workload,
}) {
  final environment = report['environment'] as JsonMap;
  requireCondition(
    environment['sourceRevision'] == sourceDigest &&
        environment['buildMode'] == buildMode &&
        environment['benchmarkProfile'] == 'production' &&
        environment['iterations'] == 50 &&
        environment['warmupIterations'] == 5,
    'Unexpected measurement environment',
  );
  final forwardNames = workload == null ? computedWorkloads : [workload];
  final expectedNames = workloadOrder == 'forward'
      ? forwardNames
      : forwardNames.reversed.toList();
  final results = report['results'] as List;
  requireCondition(
    report['methodologyVersion'] == 2 &&
        results.length == expectedNames.length &&
        report['dependencyMode'] == dependencyMode &&
        report['workloadOrder'] == workloadOrder &&
        report['workloadSelection'] == workload &&
        sameJson(report['workloadConfig'], computedWorkloadConfig),
    'Unexpected workload, tracking mode, or methodology',
  );
  final names = [for (final result in results) result['benchmark']];
  requireCondition(
    sameJson(names, expectedNames) &&
        sameJson(environment['benchmarks'], names),
    'Missing, duplicated, or reordered workload',
  );
  for (final result in results) {
    requireCondition(
      result['success'] == true &&
          result['error'] == null &&
          (result['samplesMicros'] as List).length == 50 &&
          result['warmupIterations'] == 5 &&
          result['framework'] == 'levit' &&
          result['implementation'] == 'Levit ($dependencyMode)' &&
          (result['frameTimings'] as List).isEmpty,
      'Invalid computed result: ${result['benchmark']}',
    );
  }
}

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'root',
      defaultsTo: p.dirname(p.dirname(Platform.script.toFilePath())),
    )
    ..addOption('output', mandatory: true)
    ..addOption('flutter', mandatory: true)
    ..addOption('mode', allowed: ['release', 'profile'], defaultsTo: 'release')
    ..addFlag('isolate-workloads', negatable: false);
  final args = parseOptions(
    arguments,
    parser,
    'Compare static and dynamic computed tracking in balanced native runs.',
  );
  if (args == null) return;
  final root = Directory(args.option('root')!).resolveSymbolicLinksSync();
  final output = Directory(p.absolute(args.option('output')!));
  requireCondition(
    !output.existsSync() || output.listSync().isEmpty,
    'Use an empty output directory',
  );
  output.createSync(recursive: true);
  final manifest = sourceManifest(root);
  final extraFiles = [
    'scripts/compare_computed_modes.dart',
    'scripts/src/benchmark_support.dart',
    'scripts/src/process_runner.dart',
    'pubspec.yaml',
    'pubspec.lock',
    'benchmarks/macos/Runner.xcodeproj/project.pbxproj',
    for (final file in sourceFiles(
      Directory(p.join(root, 'benchmarks/macos/Runner')),
    ))
      p.relative(file.path, from: root),
  ];
  for (final path in extraFiles) {
    if (File(p.join(root, path)).existsSync()) {
      manifest[path] = fileDigest(p.join(root, path));
    }
  }
  final digest = manifestDigest(manifest);
  writeJson(p.join(output.path, 'inputs.json'), {
    'sourceDigest': digest,
    'files': manifest,
  });
  final mode = args.option('mode')!;
  print('Building one $mode binary: $digest');
  await runLogged(
    [
      args.option('flutter')!,
      'build',
      'macos',
      '--$mode',
      '--target=lib/compare_computed_modes.dart',
      '--dart-define=BENCHMARK_REVISION=$digest',
    ],
    p.join(output.path, 'build.log'),
    workingDirectory: p.join(root, 'benchmarks'),
  );
  final binary = appBinary(root, mode);
  Map<String, String> binaryHashes() => {
    'shell': fileDigest(binary),
    'dartAot': fileDigest(appAot(binary)),
  };
  final initialHashes = binaryHashes();
  final schedule = [
    for (final workload
        in args.flag('isolate-workloads') ? computedWorkloads : <String?>[null])
      for (final (dependencyMode, order) in computedSchedule)
        (dependencyMode, order, workload),
  ];
  final runs = <JsonMap>[];
  final metadata = {
    'buildMode': mode,
    'sourceDigest': digest,
    'binaryHashes': initialHashes,
    'schedule': [
      for (final (dependencyMode, order, workload) in schedule)
        [dependencyMode, order, workload],
    ],
    'isolatedWorkloads': args.flag('isolate-workloads'),
    'runs': runs,
  };
  final reports = <JsonMap>[];
  JsonMap? referenceEnvironment;
  for (var index = 0; index < schedule.length; index++) {
    final (dependencyMode, order, workload) = schedule[index];
    final name =
        '${(index + 1).toString().padLeft(2, '0')}-$dependencyMode-$order';
    print('Running $name');
    requireCondition(
      sameJson(binaryHashes(), initialHashes),
      'Binary changed between runs',
    );
    final timer = Stopwatch()..start();
    final environment = {
      ...Platform.environment,
      'LEVIT_PERFORMANCE_RUN': '1',
      'LEVIT_DIAGNOSTICS': 'off',
      'LEVIT_COMPUTED_MODE': dependencyMode,
      'LEVIT_COMPUTED_REVERSE': order == 'reverse' ? '1' : '0',
    };
    environment.remove('LEVIT_COMPUTED_WORKLOAD');
    if (workload != null) environment['LEVIT_COMPUTED_WORKLOAD'] = workload;
    final result = await runLogged(
      [binary],
      p.join(output.path, '$name.log'),
      workingDirectory: Directory.current.path,
      environment: environment,
      timeout: const Duration(minutes: 3),
    );
    final report = extractReport(
      '${result.stdout}${result.stderr}',
      'COMPUTED_COMPARISON_JSON:',
    );
    writeJson(p.join(output.path, '$name.json'), report);
    final comparable = Map<String, dynamic>.from(report['environment'])
      ..remove('capturedAt')
      ..remove('benchmarks');
    referenceEnvironment ??= comparable;
    requireCondition(
      sameJson(comparable, referenceEnvironment),
      'Device, viewport, SDK, or build identity changed',
    );
    validateComputedReport(
      report,
      sourceDigest: digest,
      buildMode: mode,
      dependencyMode: dependencyMode,
      workloadOrder: order,
      workload: workload,
    );
    reports.add(report);
    runs.add({
      'name': name,
      'workload': workload,
      'seconds': timer.elapsedMicroseconds / 1e6,
    });
    writeJson(p.join(output.path, 'comparison.json'), metadata);
    print('Validated $name');
  }
  for (final entry in manifest.entries) {
    requireCondition(
      fileDigest(p.join(root, entry.key)) == entry.value,
      'Source input changed: ${entry.key}',
    );
  }
  writeJson(
    p.join(output.path, 'summary.json'),
    summarizeComputedReports(reports),
  );
  print(
    'Complete: 48 cases, 2400 samples, four paired comparisons per workload.',
  );
}
