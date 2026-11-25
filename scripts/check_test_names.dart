import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) {
  final root = args.isEmpty ? Directory.current : Directory(args.single);
  final violations = checkTestNames(root);
  if (violations.isEmpty) {
    print('Semantic test naming check passed.');
    return;
  }

  stderr.writeln(violations.join('\n'));
  stderr.writeln(
    'Name tests after the behavior and expected outcome they verify.',
  );
  exitCode = 1;
}

List<String> checkTestNames(Directory root) {
  final violations = <String>[];
  final files = _testFiles(root).toList()
    ..sort((first, second) => first.path.compareTo(second.path));
  for (final file in files) {
    final path = p.relative(file.path, from: root.path);
    violations.addAll(checkTestSource(path, file.readAsStringSync()));
  }
  return violations;
}

Iterable<File> _testFiles(Directory directory) sync* {
  for (final entry in directory.listSync(followLinks: false)) {
    final name = p.basename(entry.path);
    if (entry is Directory) {
      if (name.startsWith('.') ||
          const {'build', 'coverage', 'node_modules'}.contains(name)) {
        continue;
      }
      yield* _testFiles(entry);
    } else if (entry is File && name.endsWith('_test.dart')) {
      yield entry;
    }
  }
}

List<String> checkTestSource(String path, String source) {
  final violations = <String>[];
  if (p.basename(path).toLowerCase().contains('coverage')) {
    violations.add('$path:1: test filename contains "coverage".');
  }
  final result = parseString(content: source, path: path);
  result.unit.accept(_TestNameVisitor(path, result.lineInfo, violations));
  return violations;
}

class _TestNameVisitor extends RecursiveAstVisitor<void> {
  final String path;
  final LineInfo lineInfo;
  final List<String> violations;

  _TestNameVisitor(this.path, this.lineInfo, this.violations);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final method = node.methodName.name;
    if (const {'test', 'testWidgets', 'group'}.contains(method) &&
        node.argumentList.arguments.isNotEmpty) {
      final label = node.argumentList.arguments.first;
      if (_labelText(label).toLowerCase().contains('coverage')) {
        final location = lineInfo.getLocation(label.offset);
        violations.add(
          '$path:${location.lineNumber}:${location.columnNumber}: '
          '$method label contains "coverage".',
        );
      }
    }
    super.visitMethodInvocation(node);
  }
}

String _labelText(AstNode node) {
  return switch (node) {
    SimpleStringLiteral() => node.value,
    AdjacentStrings() => node.strings.map(_labelText).join(),
    StringInterpolation() => node.elements.map(_labelText).join(),
    InterpolationString() => node.value,
    InterpolationExpression() => _labelText(node.expression),
    ParenthesizedExpression() => _labelText(node.expression),
    BinaryExpression() when node.operator.lexeme == '+' =>
      _labelText(node.leftOperand) + _labelText(node.rightOperand),
    // Keep dynamic expressions separate so fragments on either side cannot
    // accidentally form a forbidden word.
    _ => '\uFFFC',
  };
}
