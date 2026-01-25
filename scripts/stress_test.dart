import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  print('Running internal stress tests and generating report...');

  final process = await Process.start(
      'flutter',
      [
        'test',
        'lib/levit_reactive',
        'lib/levit_scope',
        'lib/levit_flutter',
        '-r',
        'json',
      ],
      workingDirectory: 'stress_tests');

  final metrics = <Map<String, String>>[];
  final tests = <int, Map<String, dynamic>>{};
  final suites = <int, String>{};
  final descriptions = <int, String>{};

  Timer? watchdog;
  void resetWatchdog() {
    watchdog?.cancel();
    watchdog = Timer(const Duration(seconds: 30), () {
      print('[Watchdog] No output for 30s. Killing process...');
      process.kill();
    });
  }

  // Transform stdout to lines
  process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(
    (line) {
      resetWatchdog();
      if (line.trim().isEmpty) return;
      try {
        final event = jsonDecode(line);
        final type = event['type'];

        if (type == 'suite') {
          final suite = event['suite'];
          // Normalize path to be relative to lib/ if possible
          String path = suite['path'] as String;
          if (path.contains('lib/')) {
            path = 'lib/${path.split('lib/').last}';
          }
          suites[suite['id']] = path;
        } else if (type == 'testStart') {
          final test = event['test'];
          tests[test['id']] = test;
        } else if (type == 'testDone') {
          // Track completion if needed
        } else if (type == 'print') {
          final int? testId = event['testID'];
          final message = event['message'].toString();

          if (message.startsWith('[Description]')) {
            if (testId != null) {
              descriptions[testId] =
                  message.replaceFirst('[Description]', '').trim();
            }
          } else if (message.contains('took') ||
              message.contains(' in ') ||
              (message.contains(':') &&
                  (message.contains('ms') || message.contains('us'))) ||
              message.contains('Completed') ||
              message.contains('Captured') ||
              message.contains('time:')) {
            final test = tests[testId];
            final testName = test?['name'] ?? 'Setup/Global';
            final suiteId = test?['suiteID'];
            final suitePath = suites[suiteId] ?? 'Unknown';

            metrics.add({
              'test': testName,
              'message': message,
              'suite': suitePath,
              'description': testId != null ? (descriptions[testId] ?? '') : '',
            });
            print('[Metric] [$suitePath] $message');
          }
        } else if (type == 'done') {
          // Some test runners might hang even after 'done', force exit to be safe
          process.kill();
        }
      } catch (e) {
        // Ignore non-json lines or parse errors
      }
    },
  );

  // Close stdin to ensure the subprocess doesn't wait for input
  process.stdin.close();

  // Consume stderr to prevent the process from hanging if the buffer fills up

  // Consume stderr to prevent the process from hanging if the buffer fills up
  process.stderr.transform(utf8.decoder).listen((line) {
    stderr.write(line);
  });

  // Ensure we wait for the process to fully exit
  final exitCode = await process.exitCode;

  if (exitCode != 0) {
    print(
      'Warning: Tests failed with exit code $exitCode. Report might be incomplete.',
    );
  } else {
    print('Tests finished successfully.');
  }

  _generateMarkdownReport(metrics);
}

Future<void> _generateMarkdownReport(List<Map<String, String>> metrics) async {
  // Group metrics by category
  final reactiveMetrics =
      metrics.where((m) => m['suite']!.contains('levit_reactive')).toList();
  final diMetrics =
      metrics.where((m) => m['suite']!.contains('levit_scope')).toList();
  final flutterMetrics =
      metrics.where((m) => m['suite']!.contains('levit_flutter')).toList();

  final reportDir = Directory('reports');
  if (!await reportDir.exists()) {
    await reportDir.create(recursive: true);
  }

  // Generate Stress Test Report
  final stressBuffer = StringBuffer();
  stressBuffer.writeln('# Levit Framework Stress Test Report');
  stressBuffer.writeln();
  stressBuffer.writeln(
    '> **Generated on:** ${DateTime.now().toIso8601String().split('T')[0]}',
  );
  stressBuffer.writeln();
  stressBuffer.writeln('## Performance Summary');
  stressBuffer.writeln();
  _writeMetricsTable(stressBuffer, 'Levit Reactive (Core)', reactiveMetrics);
  stressBuffer.writeln();
  _writeMetricsTable(
      stressBuffer, 'Levit DI (Dependency Injection)', diMetrics);
  stressBuffer.writeln();
  _writeMetricsTable(
      stressBuffer, 'Levit Flutter (UI Binding)', flutterMetrics);

  stressBuffer.writeln();
  stressBuffer.writeln('## Raw Execution Logs');
  stressBuffer.writeln('<details>');
  stressBuffer.writeln('<summary>Click to view full logs</summary>');
  stressBuffer.writeln();
  stressBuffer.writeln('```text');
  for (final item in metrics) {
    stressBuffer
        .writeln('[${item['suite']}] [${item['test']}] ${item['message']}');
  }
  stressBuffer.writeln('```');
  stressBuffer.writeln('</details>');

  final stressFile = File('reports/stress_test_report.md');
  await stressFile.writeAsString(stressBuffer.toString());
  print('Stress Test Report generated: ${stressFile.absolute.path}');
}

void _writeMetricsTable(
  StringBuffer buffer,
  String title,
  List<Map<String, String>> metrics,
) {
  buffer.writeln('### $title');
  buffer.writeln();
  if (metrics.isEmpty) {
    buffer.writeln('_No metrics captured for this category._');
    return;
  }

  buffer.writeln('| Scenario | Description | Measured Action | Result |');
  buffer.writeln('| :--- | :--- | :--- | :--- |');

  final timeRegExp = RegExp(r'(\d+(?:ms|us))');

  for (final item in metrics) {
    final testName = item['test']!;
    final message = item['message']!;

    // Extract Result (Time or Count)
    String result = '-';
    String action = message;

    final timeMatch = timeRegExp.firstMatch(message);
    if (timeMatch != null) {
      result = timeMatch.group(1)!;
    } else if (message.startsWith('Completed')) {
      final parts = message.split(' ');
      if (parts.length > 1) result = parts[1];
    } else if (message.startsWith('Captured')) {
      final parts = message.split(' ');
      if (parts.length > 1) result = parts[1];
    }

    // formatting action
    if (message.contains(' took ')) {
      action = message.split(' took ')[0].trim();
    } else if (message.contains(' in ')) {
      action = message.split(' in ')[0].trim();
    } else if (message.contains(':')) {
      final parts = message.split(':');
      if (parts.length > 1) action = parts[0].trim();
    }

    // Clean up test name (remove common prefixes if redundant)
    final displayTestName = testName.replaceAll('Stress Test: ', '');
    final description = item['description'] ?? '';

    buffer
        .writeln('| $displayTestName | $description | $action | **$result** |');
  }
}
