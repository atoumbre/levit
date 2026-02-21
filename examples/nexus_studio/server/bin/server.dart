import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:nexus_studio_server/server.dart';
import 'package:nexus_studio_shared/shared.dart';

void main() async {
  // Connect to LevitDevTools in debug mode
  final transport = WebSocketTransport.connect(
    'ws://localhost:9200/ws',
    appId: 'nexus-server',
  );

  LevitMonitor.attach(transport: transport);

  // Register the core engine (singleton)
  Levit.put(() => NexusEngine());

  // Start the server controller
  Levit.put(() => ServerController());

  // Keep the process alive
  // In a real app we might listen to sigint etc.
  await Future.delayed(const Duration(days: 365));
}
