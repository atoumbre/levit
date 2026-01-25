import 'package:dev_tool_server/dev_tool_server.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';
import '../controllers/dev_tool_app_controller.dart';
import 'session_list.dart';
import 'panels/scope_tree_panel.dart';
import 'panels/variable_list_panel.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Levit Lite Client'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Reconnect logic via controller if needed
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // Left Pane: Session List
          const SizedBox(width: 300, child: SessionList()),
          const VerticalDivider(width: 1),
          // Right Pane: Details
          // We watch selectedSession
          Expanded(
            child: LWatch(() {
              final session =
                  Levit.find<DevToolAppController>().selectedSession.value;
              if (session == null) {
                return const Center(child: Text('Select a session to inspect'));
              }
              return _SessionDetails(session: session);
            }),
          ),
        ],
      ),
    );
  }
}

class _SessionDetails extends StatelessWidget {
  final AppSession session;

  _SessionDetails({required this.session});

  final controller = Levit.find<DevToolAppController>();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Scope Tree (Left Panel inside Details)
        SizedBox(
          width: 300,
          child: ScopeTreePanel(
            session: session,
            onControllerSelected: (key) {
              controller.filterControllerKey.value = key;
            },
          ),
        ),
        const VerticalDivider(width: 1),
        // Variables (Right Panel inside Details)
        Expanded(
          child: LWatch(() {
            return VariableListPanel(
              session: session,
              filterControllerKey: controller.filterControllerKey.value,
            );
          }),
        ),
      ],
    );
  }
}
