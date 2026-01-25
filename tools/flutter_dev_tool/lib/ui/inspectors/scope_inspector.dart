import 'package:dev_tool_server/dev_tool_server.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

class ScopeInspector extends StatelessWidget {
  final AppSession session;

  const ScopeInspector({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return LWatch(() {
      final scopes = session.state.scopes.values.toList();

      if (scopes.isEmpty) {
        return const Center(child: Text('No scopes detected.'));
      }

      return ListView.builder(
        itemCount: scopes.length,
        itemBuilder: (context, index) {
          final scope = scopes[index];
          final scopeDeps = session.state.dependencies.values
              .where((d) => d.scopeId == scope.id)
              .toList();

          return ExpansionTile(
            title: Text('Scope: ${scope.name} (ID: ${scope.id})'),
            initiallyExpanded: true,
            children: scopeDeps.map((dep) {
              return ListTile(
                title: Text(dep.key),
                subtitle: Text(
                  'Status: ${dep.status.name} | Lazy: ${dep.isLazy} | Async: ${dep.isAsync}',
                ),
                trailing: dep.value != null
                    ? Text(
                        '${dep.value!.substring(0, dep.value!.length.clamp(0, 20))}...',
                      )
                    : null,
              );
            }).toList(),
          );
        },
      );
    });
  }
}
