import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:levit_monitor/spi.dart';

import '../controller/inspector_controller.dart';

/// Filterable reactive variable table and dependency graph detail inspector.
class ReactiveGraphView extends StatelessWidget {
  final LevitInspectorController controller;

  const ReactiveGraphView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 16),
                    hintText: 'Filter by name, owner, or type...',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => controller.reactiveSearch.value = v,
                ),
              ),
              LWatch(() {
                final active = controller.reactiveFilter();
                return Wrap(
                  spacing: 6,
                  children: [
                    for (final mode in ReactiveFilterMode.values)
                      ChoiceChip(
                        label: Text(_labelFor(mode)),
                        selected: active == mode,
                        visualDensity: VisualDensity.compact,
                        onSelected:
                            (_) => controller.reactiveFilter.value = mode,
                      ),
                  ],
                );
              }),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: LWatch(() {
            controller.revision();
            final items = controller.filteredReactives;
            if (items.isEmpty) {
              return const Center(
                child: Text('No reactive variables match the current filter.'),
              );
            }
            final selectedId = controller.selectedReactiveId();
            final selected =
                items.where((v) => v.id == selectedId).firstOrNull ??
                items.first;

            return Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final v = items[index];
                      final unowned =
                          v.ownerId == null ||
                          v.ownerId!.isEmpty ||
                          v.ownerId == '?';
                      return ListTile(
                        dense: true,
                        selected: v.id == selected.id,
                        leading: Icon(
                          v.isSensitive
                              ? Icons.lock_outline
                              : v.dependencies.isNotEmpty
                              ? Icons.functions
                              : Icons.radio_button_checked,
                          size: 16,
                          color: unowned ? Colors.orange : null,
                        ),
                        title: Text(v.name, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${v.isSensitive ? '***' : '${v.value}'} '
                          '(${v.valueType ?? 'unknown'}) • '
                          'owner: ${v.ownerId ?? 'unowned'}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Text(
                          '${v.listenerCount} L',
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () => controller.selectedReactiveId.value = v.id,
                      );
                    },
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 2,
                  child: _ReactiveDetailPane(
                    controller: controller,
                    reactive: selected,
                  ),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }

  String _labelFor(ReactiveFilterMode mode) => switch (mode) {
    ReactiveFilterMode.all => 'All',
    ReactiveFilterMode.sensitive => 'Sensitive',
    ReactiveFilterMode.unowned => 'Unowned',
    ReactiveFilterMode.computed => 'Computed',
    ReactiveFilterMode.highListeners => 'High Listeners',
  };
}

class _ReactiveDetailPane extends StatelessWidget {
  final LevitInspectorController controller;
  final LevitReactiveModel reactive;

  const _ReactiveDetailPane({required this.controller, required this.reactive});

  @override
  Widget build(BuildContext context) {
    final upstream =
        reactive.dependencies
            .map((id) => controller.snapshot.variables[id])
            .whereType<LevitReactiveModel>()
            .toList();
    final downstream = controller.downstreamDependentsOf(reactive.id);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${reactive.name} (#${reactive.id})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _MetaRow(
          'Value',
          reactive.isSensitive ? '*** (sensitive)' : '${reactive.value}',
        ),
        _MetaRow('Type', reactive.valueType ?? 'unknown'),
        _MetaRow('Owner', reactive.ownerId ?? 'unowned'),
        _MetaRow('Active Listeners', '${reactive.listenerCount}'),
        if (reactive.scopeId != null &&
            controller.snapshot.scopes.containsKey(reactive.scopeId))
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => controller.focusScope(reactive.scopeId!),
              icon: const Icon(Icons.account_tree_outlined, size: 16),
              label: Text('Inspect Scope #${reactive.scopeId}'),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          'Upstream Dependencies (${upstream.length})',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        if (upstream.isEmpty)
          const Text('Source reactive (no upstream computed dependencies).')
        else
          ...upstream.map(
            (dep) => ListTile(
              dense: true,
              title: Text(dep.name),
              subtitle: Text(dep.isSensitive ? '***' : '${dep.value}'),
              onTap: () => controller.selectedReactiveId.value = dep.id,
            ),
          ),
        const SizedBox(height: 16),
        Text(
          'Downstream Dependents (${downstream.length})',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        if (downstream.isEmpty)
          const Text('No tracked computed dependents.')
        else
          ...downstream.map(
            (dep) => ListTile(
              dense: true,
              title: Text(dep.name),
              subtitle: Text(dep.isSensitive ? '***' : '${dep.value}'),
              onTap: () => controller.selectedReactiveId.value = dep.id,
            ),
          ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
