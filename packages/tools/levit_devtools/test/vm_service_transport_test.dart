import 'dart:convert';
import 'dart:developer' as developer;

import 'package:levit/levit.dart';
import 'package:levit_devtools/levit_devtools.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await LevitDevTools.detach();
    await Levit.reset(force: true);
    Levit.disableAutoLinking();
  });

  group('LevitVmServiceTransport and LevitDevTools', () {
    test(
      'streams redacted events and serves snapshot, history, and diagnostics',
      () async {
        final posted = <(String, Map<Object?, Object?>)>[];
        final handlers = <String, developer.ServiceExtensionHandler>{};

        final transport = LevitVmServiceTransport(
          postEvent: (kind, data) => posted.add((kind, data)),
          registerExtension: (method, handler) => handlers[method] = handler,
        );

        await LevitMonitor.attach(transport: transport, historyCapacity: 50);

        final scope = Levit.createScope('checkout');
        final secret = LxVar(
          'super-secret-token',
          isSensitive: true,
        ).named('token');
        final count = 1.lx.named('count');
        count.value = 2;
        LevitMonitor.logError('checkout failed', error: 'Timeout');

        await LevitMonitor.flush();

        expect(posted, isNotEmpty);
        expect(
          posted.every((entry) => entry.$1 == LevitDevToolsProtocol.eventKind),
          isTrue,
        );
        // Sensitive values must remain redacted in posted events.
        final serializedEvents = jsonEncode(posted.map((e) => e.$2).toList());
        expect(serializedEvents, isNot(contains('super-secret-token')));

        // Query snapshot extension.
        final snapResponse = await handlers[LevitDevToolsProtocol
            .getSnapshotExtension]!('ext.levit.getSnapshot', const {});
        final snapPayload =
            jsonDecode(snapResponse.result!) as Map<String, dynamic>;
        expect(snapPayload['attached'], isTrue);
        expect(snapPayload['protocolVersion'], 1);
        expect(snapPayload['snapshot'], isA<Map<String, dynamic>>());
        expect(snapPayload['recentErrors'], isNotEmpty);

        // Query history extension with category filter.
        final historyResponse = await handlers[LevitDevToolsProtocol
            .getHistoryExtension]!('ext.levit.getHistory', {
          'category': 'state',
          'limit': '10',
        });
        final historyPayload =
            jsonDecode(historyResponse.result!) as Map<String, dynamic>;
        expect(historyPayload['attached'], isTrue);
        final events = (historyPayload['events'] as List).cast<Map>();
        expect(events, isNotEmpty);
        expect(events.every((e) => e['category'] == 'state'), isTrue);

        // Query diagnostics extension (unowned reactives + recent errors).
        final diagResponse = await handlers[LevitDevToolsProtocol
            .getDiagnosticsExtension]!('ext.levit.getDiagnostics', const {});
        final diagPayload =
            jsonDecode(diagResponse.result!) as Map<String, dynamic>;
        final codes =
            (diagPayload['findings'] as List)
                .cast<Map>()
                .map((f) => f['code'])
                .toSet();
        expect(codes, containsAll(['unowned_reactives', 'recent_errors']));

        await secret.close();
        await count.close();
        await scope.dispose();
      },
    );

    test(
      'reports attached: false after detach and supports re-attaching cleanly',
      () async {
        final handlers = <String, developer.ServiceExtensionHandler>{};
        final transport = LevitVmServiceTransport(
          postEvent: (_, _) {},
          registerExtension: (method, handler) => handlers[method] = handler,
        );
        await LevitMonitor.attach(transport: transport, historyCapacity: 10);
        expect(LevitDevTools.isAttached, isTrue);

        await LevitDevTools.detach();
        expect(LevitDevTools.isAttached, isFalse);

        final snapResponse = await handlers[LevitDevToolsProtocol
            .getSnapshotExtension]!('ext.levit.getSnapshot', const {});
        final snapPayload =
            jsonDecode(snapResponse.result!) as Map<String, dynamic>;
        expect(snapPayload['attached'], isFalse);

        // Re-attaching via facade succeeds without duplicate extension errors.
        await LevitDevTools.attach();
        expect(LevitDevTools.isAttached, isTrue);
        await LevitDevTools.attach();
        expect(LevitDevTools.isAttached, isTrue);
      },
    );

    test(
      'drops events after close and handles postEvent errors safely',
      () async {
        var shouldThrow = true;
        final transport = LevitVmServiceTransport(
          postEvent: (_, _) {
            if (shouldThrow) throw StateError('transport unavailable');
          },
          registerExtension: (_, _) {},
        );
        await LevitMonitor.attach(transport: transport);
        LevitMonitor.logInfo('first');
        await LevitMonitor.flush();
        expect(transport.droppedEvents, greaterThanOrEqualTo(1));

        shouldThrow = false;
        await transport.close();
        expect(LevitDevTools.isAttached, isFalse);
      },
    );
  });
}
