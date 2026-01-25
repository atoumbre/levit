import 'package:dev_tool_server/dev_tool_server.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

class ReactiveInspector extends StatelessWidget {
  final AppSession session;

  const ReactiveInspector({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return LWatch(() {
      final variables = session.state.variables.values.toList();

      if (variables.isEmpty) {
        return const Center(child: Text('No reactive state detected.'));
      }

      return ListView.builder(
        itemCount: variables.length,
        itemBuilder: (context, index) {
          final reactive = variables[index];
          return ListTile(
            title: Text(reactive.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${reactive.valueType ?? "dynamic"}: ${reactive.value}'),
                if (reactive.ownerKey != null)
                  Text(
                    'Controller: ${reactive.ownerKey}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                if (reactive.scopeId != null)
                  Text(
                    'Scope: ${reactive.scopeId}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
            isThreeLine: true,
            trailing: Text('ID: ${reactive.id}'),
          );
        },
      );
    });
  }
}
