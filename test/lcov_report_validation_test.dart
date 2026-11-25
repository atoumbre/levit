import 'dart:io';
import 'dart:mirrors';

import 'package:test/test.dart';

import '../scripts/check_coverage.dart' as coverage;

void main() {
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('levit_lcov_test_');
  });

  tearDown(() => directory.deleteSync(recursive: true));

  test('counts every instrumented library line, including callbacks', () {
    final source = File('${directory.path}/lib/middleware.dart');
    source.parent.createSync(recursive: true);
    source.writeAsStringSync('''
void remove(Object middleware) {
  tokens.removeWhere(
    (_, registered) => identical(registered, middleware),
  );
}
''');
    final lcov = File('${directory.path}/lcov.info')
      ..writeAsStringSync('''
SF:${source.path}
DA:1,1
DA:2,1
DA:3,0
DA:4,1
DA:5,1
end_of_record
''');

    final stats = parseLcov(lcov);
    expect(stats.totalLines, 5);
    expect(stats.coveredLines, 4);
    expect(stats.coveragePercent, 80);
    expect(stats.uncoveredFiles, {
      source.path: [3],
    });
  });

  test('merges repeated records and includes generated library files', () {
    final lcov = File('${directory.path}/lcov.info')
      ..writeAsStringSync('''
SF:lib/runtime.dart
DA:1,0
DA:2,1
end_of_record
SF:lib/runtime.dart
DA:1,1
DA:2,0
end_of_record
SF:lib/model.g.dart
DA:3,0
end_of_record
SF:lib/model.freezed.dart
DA:4,1
end_of_record
SF:test/runtime_test.dart
DA:5,0
end_of_record
''');

    final stats = parseLcov(lcov);
    expect(stats.totalLines, 4);
    expect(stats.coveredLines, 3);
    expect(stats.uncoveredFiles, {
      'lib/model.g.dart': [3],
    });
  });

  test('a missing LCOV report raises a file-system error', () {
    expect(
      () => parseLcov(File('${directory.path}/missing.info')),
      throwsA(isA<FileSystemException>()),
    );
  });

  for (final directive in ['line', 'start', 'end', 'file']) {
    test('rejects ignore-$directive exclusions in library sources', () {
      final source = File('${directory.path}/lib/nested/source.dart');
      source.parent.createSync(recursive: true);
      source.writeAsStringSync('// coverage:ignore-$directive\n');
      final library =
          reflectClass(coverage.PackageStats).owner as LibraryMirror;
      final ignoredFiles = library.invoke(
        MirrorSystem.getSymbol('_coverageIgnoreFiles', library),
        [directory],
      ).reflectee;
      expect(ignoredFiles, [source.path]);
    });
  }
}

coverage.PackageStats parseLcov(File file) {
  final library = reflectClass(coverage.PackageStats).owner as LibraryMirror;
  return library.invoke(MirrorSystem.getSymbol('_parseLcov', library), [
        file,
        'fixture',
      ]).reflectee
      as coverage.PackageStats;
}
