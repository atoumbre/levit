import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:levit_monitor/spi.dart';

import '../controller/inspector_controller.dart';

/// Displays the live DI scope hierarchy and selected scope registrations.
class ScopeTreeView extends StatelessWidget {
  final LevitInspectorController controller;

  const ScopeTreeView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return LWatch(() {
      controller.revision();
      final scopes = controller.snapshot.scopes;
      if (scopes.isEmpty) {
        return const Center(child: Text('No active scopes recorded yet.'));
      }

      final flattened = _flattenScopeTree(scopes);
      final selectedId =
          controller.selectedScopeId() ?? flattened.first.scope.id;
      final selectedScope = scopes[selectedId] ?? flattened.first.scope;

      return Row(
        children: [
          Expanded(
            flex: 2,
            child: ListView.builder(
              itemCount: flattened.length,
              itemBuilder: (context, index) {
                final node = flattened[index];
                final scope = node.scope;
                final isSelected = scope.id == selectedScope.id;
                final isClosing = scope.progress['isClosing'] == true;
                final pending =
                    scope.progress['pendingInitializations'] as int? ?? 0;
                final depCount =
                    controller.snapshot.dependencies.values
                        .where((d) => d.scopeId == scope.id)
                        .length;

                return ListTile(
                  dense: true,
                  selected: isSelected,
                  contentPadding: EdgeInsets.only(
                    left: 12.0 + (node.depth * 18.0),
                    right: 12,
                  ),
                  leading: Icon(
                    isClosing
                        ? Icons.hourglass_bottom
                        : Icons.account_tree_outlined,
                    size: 16,
                    color: isClosing ? Colors.orange : null,
                  ),
                  title: Text(
                    '${scope.name} (#${scope.id})',
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '$depCount dep(s)'
                    '${pending > 0 ? ' • $pending pending' : ''}'
                    '${isClosing ? ' • closing' : ''}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  onTap: () => controller.selectedScopeId.value = scope.id,
                );
              },
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 3,
            child: _ScopeDetailPane(
              controller: controller,
              scope: selectedScope,
            ),
          ),
        ],
      );
    });
  }

  List<_ScopeTreeNode> _flattenScopeTree(Map<int, LevitScopeModel> scopes) {
    final childrenByParent = <int?, List<LevitScopeModel>>{};
    for (final scope in scopes.values) {
      final parentId =
          scope.parentScopeId != null && scopes.containsKey(scope.parentScopeId)
              ? scope.parentScopeId
              : null;
      childrenByParent.putIfAbsent(parentId, () => []).add(scope);
    }
    for (final list in childrenByParent.values) {
      list.sort((a, b) => a.id.compareTo(b.id));
    }

    final result = <_ScopeTreeNode>[];
    final visited = <int>{};
    void visit(LevitScopeModel scope, int depth) {
      if (!visited.add(scope.id)) return;
      result.add(_ScopeTreeNode(scope, depth));
      for (final child in childrenByParent[scope.id] ?? const []) {
        visit(child, depth + 1);
      }
    }

    for (final root in childrenByParent[null] ?? const []) {
      visit(root, 0);
    }
    return result;
  }
}

class _ScopeTreeNode {
  final LevitScopeModel scope;
  final int depth;

  const _ScopeTreeNode(this.scope, this.depth);
}

class _ScopeDetailPane extends StatelessWidget {
  final LevitInspectorController controller;
  final LevitScopeModel scope;

  const _ScopeDetailPane({required this.controller, required this.scope});

  @override
  Widget build(BuildContext context) {
    final deps =
        controller.snapshot.dependencies.values
            .where((d) => d.scopeId == scope.id)
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    final ownedReactives =
        controller.snapshot.variables.values
            .where((v) => v.scopeId == scope.id)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final progressRegs =
        (scope.progress['registrations'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${scope.name} (scope #${scope.id})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            Chip(
              label: Text(
                scope.parentScopeId == null
                    ? 'Root Scope'
                    : 'Parent #${scope.parentScopeId}',
              ),
              visualDensity: VisualDensity.compact,
            ),
            if (scope.progress['isClosing'] == true)
              const Chip(
                label: Text('Closing'),
                backgroundColor: Color(0x33FF9800),
                visualDensity: VisualDensity.compact,
              ),
            if ((scope.progress['pendingInitializations'] as int? ?? 0) > 0)
              Chip(
                label: Text(
                  'Pending Init: ${scope.progress['pendingInitializations']}',
                ),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Registrations (${deps.isNotEmpty ? deps.length : progressRegs.length})',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (deps.isEmpty && progressRegs.isEmpty)
          const Text('No registrations in this scope.')
        else if (deps.isNotEmpty)
          ...deps.map(
            (dep) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                title: Text(dep.key),
                subtitle: Text(
                  '${dep.type.name} • ${dep.status.name}'
                  '${dep.isLazy ? ' • lazy' : ''}'
                  '${dep.isFactory ? ' • factory' : ''}'
                  '${dep.isAsync ? ' • async' : ''}',
                ),
              ),
            ),
          )
        else
          ...progressRegs.map(
            (reg) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                title: Text('${reg['key']} (${reg['type']})'),
                subtitle: Text(
                  '${reg['isInstantiated'] == true ? 'instantiated' : 'registered'}'
                  '${reg['aliasOf'] != null ? ' • aliasOf ${reg['aliasOf']}' : ''}'
                  '${reg['permanent'] == true ? ' • permanent' : ''}'
                  '${reg['isFactory'] == true ? ' • factory' : ''}',
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          'Owned Reactives (${ownedReactives.length})',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (ownedReactives.isEmpty)
          const Text('No reactive variables linked to this scope.')
        else
          ...ownedReactives.map(
            (v) => ListTile(
              dense: true,
              title: Text(v.name),
              subtitle: Text(
                '${v.isSensitive ? '***' : '${v.value}'} • ${v.listenerCount} listener(s)',
              ),
              trailing: const Icon(Icons.chevron_right, size: 16),
              onTap: () => controller.focusReactive(v.id),
            ),
          ),
      ],
    );
  }
}
