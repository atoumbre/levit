import 'package:levit_monitor/spi.dart';
import 'package:test/test.dart';

void main() {
  group('LevitDiagnosticFinding serialization', () {
    test('serializes code, severity, message, and optional details', () {
      const bare = LevitDiagnosticFinding(
        code: 'unowned_reactives',
        severity: LevitDiagnosticSeverity.warning,
        message: '1 reactive has no owner',
      );
      expect(bare.toJson(), {
        'code': 'unowned_reactives',
        'severity': 'warning',
        'message': '1 reactive has no owner',
      });

      const detailed = LevitDiagnosticFinding(
        code: 'recent_errors',
        severity: LevitDiagnosticSeverity.error,
        message: '1 runtime error captured',
        details: {'count': 1},
      );
      expect(detailed.toJson(), {
        'code': 'recent_errors',
        'severity': 'error',
        'message': '1 runtime error captured',
        'details': {'count': 1},
      });
    });
  });
}
