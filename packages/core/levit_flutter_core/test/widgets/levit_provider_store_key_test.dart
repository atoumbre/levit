import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  setUp(() {
    Levit.reset(force: true);
  });

  tearDown(() {
    Levit.reset(force: true);
  });

  testWidgets('LevitProvider supports LevitStore/LevitAsyncStore as keys',
      (tester) async {
    final asyncStore = LevitStore.async((_) async => 42);
    final futureStore = LevitStore((_) => Future.value('hello'));

    Future<int>? fromFindAsyncStore;
    Future<int>? fromFindOrNullAsyncStore;
    Future<int?>? fromFindOrNullAsyncStoreAsync;
    Future<String>? fromFindAsyncFutureStore;

    bool? isRegisteredBefore;
    bool? isInstantiatedBefore;
    bool? isRegisteredAfter;
    bool? isInstantiatedAfter;

    await tester.pumpWidget(
      MaterialApp(
        home: LScope(
          dependencyFactory: (scope) => scope.put(() => 'seed'),
          child: Builder(
            builder: (context) {
              isRegisteredBefore = context.levit.isRegistered(key: asyncStore);
              isInstantiatedBefore =
                  context.levit.isInstantiated(key: asyncStore);

              fromFindAsyncStore =
                  context.levit.find<Future<int>>(key: asyncStore);
              fromFindOrNullAsyncStore =
                  context.levit.findOrNull<Future<int>>(key: asyncStore);
              fromFindOrNullAsyncStoreAsync =
                  context.levit.findOrNullAsync<int>(key: asyncStore);

              // This exercises the "double await" path for LevitStore values
              // that are Future<T>.
              fromFindAsyncFutureStore =
                  context.levit.findAsync<String>(key: futureStore);

              isRegisteredAfter = context.levit.isRegistered(key: asyncStore);
              isInstantiatedAfter =
                  context.levit.isInstantiated(key: asyncStore);

              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(isRegisteredBefore, isFalse);
    expect(isInstantiatedBefore, isFalse);
    expect(isRegisteredAfter, isTrue);
    expect(isInstantiatedAfter, isTrue);

    await tester.runAsync(() async {
      expect(await fromFindAsyncStore, 42);
      expect(await fromFindOrNullAsyncStore, 42);
      expect(await fromFindOrNullAsyncStoreAsync, 42);
      expect(await fromFindAsyncFutureStore, 'hello');
    });
  });
}
