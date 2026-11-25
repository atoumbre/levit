import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:nexus_studio_server/server.dart';
import 'package:nexus_studio_shared/shared.dart';

Future<void> main() async {
  Levit.enableAutoLinking();
  // Connect to LevitDevTools in debug mode
  final transport = LevitWebSocketTransport.connect(
    const String.fromEnvironment(
      'LEVIT_INSPECTOR_URL',
      defaultValue: 'ws://127.0.0.1:9200/ws',
    ),
    appId: 'nexus-server',
    onError: (e) =>
        print('⚠️ DevTool Server not available. Running without monitoring.'),
  );

  await LevitMonitor.attach(
    transport: transport,
    historyCapacity: 1000,
    includeStackTrace: true,
    enableWorkerStatistics: true,
  );

  // Register the core engine (singleton)
  Levit.put(() => NexusEngine());

  // Start the server controller
  Levit.put(() => ServerController());

  // Keep the process alive
  // In a real app we might listen to sigint etc.
  await Future.delayed(const Duration(days: 365));
}
