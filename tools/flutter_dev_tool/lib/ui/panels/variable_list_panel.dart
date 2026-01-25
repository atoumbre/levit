import 'package:flutter/material.dart';
import 'package:dev_tool_server/dev_tool_server.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

class VariableListPanel extends StatelessWidget {
  final AppSession session;
  final String? filterControllerKey;

  const VariableListPanel({
    super.key,
    required this.session,
    this.filterControllerKey,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8.0),
          width: double.infinity,
          color: Colors.grey[200],
          child: Text(
            filterControllerKey != null
                ? 'Variables in $filterControllerKey'
                : 'All Reactive Variables',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: LWatch(() {
            var variables = session.state.variables.values.toList();

            // Apply filter logic if we assume controller selection works by filtering
            // Note: filterControllerKey from tree usually is "ScopeID:Key".
            // Reactive ownerId format matches "ScopeID:Key".
            // So exact match should work.

            if (filterControllerKey != null) {
              // We might need fuzzy match if "Key" is just "Key" but ownerId contains ScopeID
              // But the tree sets filter key as "ScopeID:Key" (see ScopeTreePanel).
              // And ReactiveModel ownerId is parsed. We can check `ownerId` directly.
              variables = variables
                  .where((v) => v.ownerId == filterControllerKey)
                  .toList();
            }

            if (variables.isEmpty) {
              return const Center(child: Text('No variables found'));
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: variables.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _VariableCard(
                  variable: variables[index],
                  session: session,
                );
              },
            );
          }),
        ),
      ],
    );
  }
}

class _VariableCard extends StatelessWidget {
  final ReactiveModel variable;
  final AppSession session;

  const _VariableCard({required this.variable, required this.session});

  @override
  Widget build(BuildContext context) {
    // Compute dependents count (simplistic view: how many other vars reference this one?)
    // This is O(N*M) where N=vars, M=dependencies. Fine for devtools.
    final dependentsCount = session.state.variables.values
        .where((v) => v.dependencies.contains(variable.id))
        .length;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Name and Type
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  variable.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(
                  label: Text(
                    variable.valueType ?? 'dynamic',
                    style: const TextStyle(fontSize: 10),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.blue.shade50,
                ),
              ],
            ),
            const Divider(),

            // Value
            const Text(
              'Value:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${variable.value}',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 12),

            // Metadata Grid
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Controllers / Owner
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Owner',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      if (variable.ownerKey != null)
                        Text(
                          'Controller: ${variable.ownerKey}',
                          style: const TextStyle(fontSize: 12),
                        )
                      else if (variable.scopeId != null)
                        Text(
                          'Scope: ${variable.scopeId}',
                          style: const TextStyle(fontSize: 12),
                        )
                      else
                        const Text(
                          'Unknown',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),

                // Listeners
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Listeners',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${variable.listenerCount} active',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),

                // Dependents
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dependents',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '$dependentsCount downstream',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Dependencies (if any)
            if (variable.dependencies.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Dependencies (Upstream):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              Wrap(
                spacing: 4,
                children: variable.dependencies.map((depId) {
                  // Try to find name of dependency
                  final depName =
                      session.state.variables[depId]?.name ?? 'ID:$depId';
                  return Chip(
                    label: Text(depName, style: const TextStyle(fontSize: 10)),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
