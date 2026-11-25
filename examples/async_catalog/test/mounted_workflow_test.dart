import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:levit_example_async_catalog/catalog.dart';
import 'package:levit_example_async_catalog/main.dart';

void main() {
  testWidgets(
    'favorite-only edit rebuilds one catalog row while saving stays idle',
    (tester) async {
      final controller = CatalogController();
      final calls = List<int>.filled(6, 0);
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              for (var id = 0; id < calls.length; id++)
                LWatch(() {
                  calls[id]++;
                  return Text(
                    '${controller.isFavorite(CatalogItem(id, "item"))}',
                  );
                }),
            ],
          ),
        ),
      );
      expect(calls, [1, 1, 1, 1, 1, 1]);
      controller.favorites[2] = true;
      await tester.pump();
      expect(calls, [1, 1, 2, 1, 1, 1]);
      expect(controller.saving.isEmpty, true);
      await tester.pumpWidget(const SizedBox());
      await controller.onClose();
    },
  );
  testWidgets(
    'mounted search, pagination, refresh, rollback and route cleanup',
    (tester) async {
      Levit.enableAutoLinking();
      await tester.pumpWidget(const AsyncCatalogApp());
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(TextField));
      final controller = context.levit.find<CatalogController>();
      final scope = LScope.of(context)!;
      expect(find.text('Package 1'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Package 7'), findsOneWidget);
      expect(find.text('Package 1'), findsNothing);
      await tester.tap(find.text('Previous'));
      await tester.pumpAndSettle();
      expect(find.text('Package 1'), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.tap(find.byTooltip('Toggle favorite').first);
      await tester.pump();
      expect(find.byIcon(Icons.star), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.star), findsNothing);
      expect(find.textContaining('favorite was restored'), findsOneWidget);

      await tester.tap(find.byTooltip('Toggle favorite').first);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.star), findsOneWidget);
      final handle = controller.queries.entry(controller.key.value);
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(controller.queries.entry(controller.key.value), same(handle));
      expect(find.byIcon(Icons.star), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Package 24');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Package 24'), findsOneWidget);
      expect(find.text('Package 1'), findsNothing);
      expect(find.text('Page 1'), findsOneWidget);

      // Close while the real repository's delayed request is still outstanding.
      await tester.enterText(find.byType(TextField), 'Package 2');
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await scope.disposed;
      expect(controller.isClosed, isTrue);
      await Levit.reset(force: true);
    },
  );
}
