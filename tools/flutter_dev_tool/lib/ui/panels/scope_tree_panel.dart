import 'package:flutter/material.dart';
import 'package:dev_tool_server/dev_tool_server.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

class ScopeTreePanel extends StatelessWidget {
  final AppSession session;
  final ValueChanged<String?>? onControllerSelected;

  const ScopeTreePanel({
    super.key,
    required this.session,
    this.onControllerSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8.0),
          width: double.infinity,
          color: Colors.grey[200],
          child: const Text(
            'Scopes & Controllers',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: LWatch(() {
            final scopes = session.state.scopes.values.toList();
            if (scopes.isEmpty) {
              return const Center(child: Text('No scopes'));
            }

            return ListView.builder(
              itemCount: scopes.length,
              itemBuilder: (context, index) {
                final scope = scopes[index];
                final scopeDeps = session.state.dependencies.values
                    .where((d) => d.scopeId == scope.id)
                    .toList();

                return _ScopeNode(
                  scope: scope,
                  dependencies: scopeDeps,
                  onControllerSelected: onControllerSelected,
                );
              },
            );
          }),
        ),
      ],
    );
  }
}

class _ScopeNode extends StatelessWidget {
  final ScopeModel scope;
  final List<DependencyModel> dependencies;
  final ValueChanged<String?>? onControllerSelected;

  const _ScopeNode({
    required this.scope,
    required this.dependencies,
    this.onControllerSelected,
  });

  @override
  Widget build(BuildContext context) {
    // We treat scope dependencies that ARE controllers as children nodes
    // How do we know if a dependency is a controller?
    // We don't have explicit type info saying "isController" in DependencyModel yet.
    // But we know that controllers usually register themselves.
    // For now, let's list ALL dependencies under the scope.

    return ExpansionTile(
      title: Text(
        scope.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('ID: ${scope.id}'),
      initiallyExpanded: true,
      children: dependencies.map((dep) {
        return InkWell(
          onTap: () => onControllerSelected?.call('${scope.id}:${dep.key}'),
          child: Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 4, bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.extension, size: 16, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dep.key, style: const TextStyle(fontSize: 14)),
                      Text(
                        '${dep.status.name}${dep.isLazy ? " (Lazy)" : ""}${dep.isAsync ? " (Async)" : ""}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
