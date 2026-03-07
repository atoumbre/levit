import 'dart:async';
import 'package:test/test.dart';
import 'package:levit_dart_core/levit_dart_core.dart';

void main() {
  setUp(() {
    Levit.enableAutoLinking();
  });

  tearDown(() {
    Levit.reset(force: true);
    Levit.disableAutoLinking();
  });

  group('AutoLinking Assertion Coverage', () {
    test(
        'prints warning when reactive created in active scope but without capture list in zone',
        () {
      // Capture printed output
      final printLogs = <String>[];
      final spec = ZoneSpecification(
        print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
          printLogs.add(line);
        },
      );

      runZoned(() {
        runCapturedForTesting(() {
          // Now we are inside a capture scope (_activeCaptureScopes > 0)
          // But we need to erase the captureKey from the Zone.
          final erasedZone = Zone.current.fork(zoneValues: {
            // Overwrite the capture list with null
            autoLinkCaptureKeyForTesting: null,
          });

          erasedZone.run(() {
            // Creating an LxInt here should trigger the specific assert.
            0.lx.named('ErasedTestVar');
          });
        });
      }, zoneSpecification: spec);

      expect(
        printLogs.any((line) => line.contains(
            'created inside an active capture scope but no capture list')),
        isTrue,
        reason: 'Should have printed the missing capture list warning.',
      );
    });
  });
}
