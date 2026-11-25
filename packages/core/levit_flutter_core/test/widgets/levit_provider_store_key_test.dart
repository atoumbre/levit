import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  testWidgets('typed store access uses the nearest scope and local overrides', (
    tester,
  ) async {
    final first = LevitStore((_) => 7);
    final second = LevitStore((_) => 9);
    final remote = LevitAsyncStore((_) async => 42);
    late LevitScope parent;
    final outer = LevitScopeLifecycleController();
    final lifecycle = LevitScopeLifecycleController();
    late Future<int> resolved;
    late Future<int> resolvedSync;
    await tester.pumpWidget(
      MaterialApp(
        home: LScope(
          lifecycle: outer,
          configure: (scope) {
            parent = scope;
            first.findIn(scope);
          },
          child: LScope(
            lifecycle: lifecycle,
            configure: (scope) => scope.applyOverrides([
              first.overrideWith((_) => 11),
              remote.overrideWith((_) async => 88),
            ]),
            child: Builder(
              builder: (context) {
                expect(context.levit.isAsyncStoreRegistered(remote), isTrue);
                expect(context.levit.isAsyncStoreInstantiated(remote), isFalse);
                expect(context.levit.findStore(first, tag: 'same'), 7);
                expect(context.levit.findStore(second, tag: 'same'), 9);
                expect(context.levit.findStore(first), 11);
                resolved = context.levit.findAsyncStore(
                  remote,
                  localOnly: true,
                );
                resolvedSync = Future.value(context.levit.findStore(second));
                expect(context.levit.isStoreRegistered(first), isTrue);
                expect(context.levit.isStoreInstantiated(first), isTrue);
                expect(context.levit.isAsyncStoreInstantiated(remote), isTrue);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    expect(await resolved, 88);
    expect(await resolvedSync, 9);
    expect(first.findIn(parent), 7);
    await tester.pumpWidget(const SizedBox());
    await lifecycle.closed;
    await outer.closed;
  });
}
