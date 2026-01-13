import 'package:levit_dart/levit_dart.dart';
import 'package:shared/shared.dart';
import 'package:nexus_server/server.dart';

void main() async {
  // Register the core engine (singleton)
  Levit.put(() => NexusEngine());

  // Start the server controller
  Levit.put(() => ServerController());

  // Keep the process alive
  // In a real app we might listen to sigint etc.
  await Future.delayed(const Duration(days: 365));
}
