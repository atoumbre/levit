import 'dart:math';

import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

void main() {
  runApp(const AsyncCatalogApp());
}

class AsyncCatalogApp extends StatelessWidget {
  const AsyncCatalogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AsyncCatalogScreen(),
    );
  }
}

class CatalogController extends LevitController {
  final catalogStatus =
      LxVar<LxStatus<List<String>>>(LxIdle<List<String>>()).named('catalog');
  final selectedCategory = 'all'.lx.named('selectedCategory');
  final _random = Random();

  static const _allItems = <String>[
    'Reactive Core',
    'Scoped Controllers',
    'Typed Stores',
    'Async Views',
    'Monitor Pipeline',
    'Bridge Middleware',
  ];

  @override
  void onInit() {
    super.onInit();
    autoDispose(catalogStatus);
    autoDispose(selectedCategory);
    refresh();
  }

  Future<void> refresh() async {
    final previous = catalogStatus.value.lastValue;
    catalogStatus.value = LxWaiting(previous);
    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (_random.nextInt(4) == 0) {
      catalogStatus.value = LxError(
        'Network timeout. Retry to reload.',
        null,
        previous,
      );
      return;
    }

    final sorted = List<String>.from(_allItems)..sort();
    catalogStatus.value = LxSuccess(sorted);
  }
}

class AsyncCatalogScreen extends StatelessWidget {
  const AsyncCatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LScopedView.put(
      () => CatalogController(),
      builder: (context, controller) => Scaffold(
        appBar: AppBar(
          title: const Text('Async Catalog'),
          actions: [
            IconButton(
              onPressed: controller.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: LStatusBuilder<List<String>>(
            controller.catalogStatus,
            onIdle: () => const Center(child: Text('Initializing catalog...')),
            onWaiting: () => const Center(
              child: CircularProgressIndicator(),
            ),
            onError: (error, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error.toString()),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: controller.refresh,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            onSuccess: (items) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Loaded packages',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (context, index) => ListTile(
                      title: Text(items[index]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
