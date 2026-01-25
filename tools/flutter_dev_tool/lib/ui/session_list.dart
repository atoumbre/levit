import 'package:flutter/material.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';
import '../controllers/dev_tool_app_controller.dart';

class SessionList extends StatelessWidget {
  const SessionList({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.levit.find<DevToolAppController>();
    // Watch the sessions map directly. LxMap notifies on structure change.
    // LWatch handles it.
    return LWatch(() {
      final sessions = controller.server.sessions.values
          .where((s) => s.isConnected.value)
          .toList();

      final selected = controller.selectedSession.value;

      return ListView.builder(
        itemCount: sessions.length,
        itemBuilder: (context, index) {
          final session = sessions[index];
          final isSelected = session == selected;
          return ListTile(
            title: Text(session.appId ?? session.sessionId),
            subtitle: Text(
              session.appId != null
                  ? session.sessionId
                  : session.connectedAt.toString(),
            ),
            selected: isSelected,
            onTap: () {
              controller.selectedSession.value = session;
            },
            leading: const Icon(Icons.devices),
          );
        },
      );
    });
  }
}
