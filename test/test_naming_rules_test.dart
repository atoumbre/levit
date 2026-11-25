import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../scripts/check_test_names.dart';

void main() {
  test('rejects the banned fragment in test filenames regardless of case', () {
    expect(checkTestSource('test/Coverage_gaps_test.dart', ''), [
      'test/Coverage_gaps_test.dart:1: test filename contains "coverage".',
    ]);
  });

  for (final method in ['test', 'testWidgets', 'group', 'tests.test']) {
    test('reports the source location of a banned $method label', () {
      final violations = checkTestSource('test/example_test.dart', '''
void main() {
  $method(
    'COVERAGE gaps',
    () {},
  );
}
''');
      expect(violations, hasLength(1));
      expect(violations.single, startsWith('test/example_test.dart:3:5:'));
    });
  }

  test(
    'rejects adjacent, concatenated, raw, escaped, and multiline labels',
    () {
      final violations = checkTestSource('test/example_test.dart', r'''
void main() {
  test('cov' 'erage', () {});
  test(('COV' + 'ERAGE'), () {});
  test(r'coverage gaps', () {});
  test('\u0063overage gaps', () {});
  group("""additional
coverage""", () {});
}
''');
      expect(violations, hasLength(5));
    },
  );

  test('rejects banned text in interpolated labels and nested groups', () {
    final violations = checkTestSource('test/example_test.dart', r'''
void main() {
  group('middleware removal', () {
    test('coverage for $scenario', () {});
    test('${"cov"}erage', () {});
  });
}
''');
    expect(violations, hasLength(2));
  });

  test('allows descriptive labels and preserves dynamic label boundaries', () {
    expect(
      checkTestSource('test/lcov_report_validation_test.dart', r'''
void main() {
  group('middleware removal', () {
    test('clears tokens for $scenario', () {});
    test('cov${scenario}erage', () {});
    testWidgets(framework.label, (tester) async {});
  });
}
'''),
      isEmpty,
    );
  });

  test('allows comments, fixture strings, and ordinary body text', () {
    expect(
      checkTestSource('test/lcov_report_validation_test.dart', r'''
// test('coverage gaps', () {});
/* group('coverage', () {}); */
void main() {
  test('rejects ignore directives', () {
    final fixture = "test('coverage gaps', () {});";
    final ignore = '// coverage:ignore-line';
    expect(fixture, contains('coverage'));
    expect(ignore, contains('coverage'));
  });
}
'''),
      isEmpty,
    );
  });

  test('scans nested source tests while skipping generated directories', () {
    final root = Directory.systemTemp.createTempSync('levit_test_names_');
    addTearDown(() => root.deleteSync(recursive: true));
    final nested = File(p.join(root.path, 'packages', 'demo', 'bad_test.dart'));
    nested.parent.createSync(recursive: true);
    nested.writeAsStringSync("void main() { test('coverage', () {}); }");
    for (final folder in ['.dart_tool', 'build', 'coverage', 'node_modules']) {
      final generated = File(p.join(root.path, folder, 'coverage_test.dart'));
      generated.parent.createSync(recursive: true);
      generated.writeAsStringSync("void main() { test('coverage', () {}); }");
    }
    final helper = File(p.join(root.path, 'fixture.dart'));
    helper.writeAsStringSync("void main() { test('coverage', () {}); }");

    final violations = checkTestNames(root);
    expect(violations, hasLength(1));
    expect(
      violations.single,
      startsWith(p.join('packages', 'demo', 'bad_test.dart')),
    );
  });

  test('command exits unsuccessfully and identifies an invalid test', () async {
    final root = Directory.systemTemp.createTempSync('levit_test_names_cli_');
    addTearDown(() => root.deleteSync(recursive: true));
    File(p.join(root.path, 'coverage_test.dart')).writeAsStringSync('');
    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      'scripts/check_test_names.dart',
      root.path,
    ]);
    expect(result.exitCode, 1);
    expect(result.stderr, contains('coverage_test.dart:1:'));
  });
}
