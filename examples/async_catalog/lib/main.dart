import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'catalog.dart';

void main() {
  Levit.enableAutoLinking();
  runApp(const AsyncCatalogApp());
}

class AsyncCatalogApp extends StatelessWidget {
  const AsyncCatalogApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: AsyncCatalogScreen(),
  );
}

class AsyncCatalogScreen extends StatelessWidget {
  const AsyncCatalogScreen({super.key});
  @override
  Widget build(BuildContext context) => LScopedView<CatalogController>.put(
    () => CatalogController(),
    autoWatch: false,
    builder: (context, controller) => Scaffold(
      appBar: AppBar(
        title: const Text('Searchable catalog'),
        actions: [
          IconButton(
            onPressed: controller.refresh,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              onChanged: controller.search,
              decoration: const InputDecoration(
                labelText: 'Search packages',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            LWatch(
              () => SwitchListTile(
                title: const Text('Reject next save to demonstrate rollback'),
                value: controller.failNextSave.value,
                onChanged: (value) => controller.failNextSave.value = value,
              ),
            ),
            LWatch(
              () => controller.message.value == null
                  ? const SizedBox.shrink()
                  : Text(controller.message.value!),
            ),
            Expanded(
              child: LWatch(
                () => LStatusBuilder<CatalogPage>(
                  controller.queries.entry(controller.key.value),
                  onWaiting: (status) => Column(
                    children: [
                      const LinearProgressIndicator(),
                      if (status.hasLastValue)
                        Expanded(
                          child: _Results(controller, status.lastValue!),
                        ),
                    ],
                  ),
                  onError: (status) => Column(
                    children: [
                      Text('Unable to refresh: ${status.error}'),
                      TextButton(
                        onPressed: controller.refresh,
                        child: const Text('Retry'),
                      ),
                      if (status.hasLastValue)
                        Expanded(
                          child: _Results(controller, status.lastValue!),
                        ),
                    ],
                  ),
                  onSuccess: (page) => _Results(controller, page),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Results extends StatelessWidget {
  const _Results(this.controller, this.page);
  final CatalogController controller;
  final CatalogPage page;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: page.items.isEmpty
            ? const Center(child: Text('No matches'))
            : ListView(
                children: [
                  for (final item in page.items)
                    LWatch(
                      () => ListTile(
                        key: ValueKey(item.id),
                        title: Text(item.title),
                        trailing: IconButton(
                          tooltip: 'Toggle favorite',
                          onPressed: controller.saving.contains(item.id)
                              ? null
                              : () => controller.toggleFavorite(item),
                          icon: Icon(
                            controller.isFavorite(item)
                                ? Icons.star
                                : Icons.star_border,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
      LWatch(
        () => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: controller.key.value.page == 0
                  ? null
                  : controller.previousPage,
              child: const Text('Previous'),
            ),
            Text('Page ${controller.key.value.page + 1}'),
            TextButton(
              onPressed: page.hasMore ? controller.nextPage : null,
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    ],
  );
}
