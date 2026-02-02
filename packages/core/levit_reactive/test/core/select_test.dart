import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('LxBase.select', () {
    test('should return a computed that updates when selected value changes',
        () {
      final state = {'count': 0, 'data': 'initial'}.lx;

      // Select only the 'count' property
      final countSelect = state.select((val) => val['count']);

      expect(countSelect.value, 0);

      // Verify updates
      state.value = {'count': 1, 'data': 'initial'};
      expect(countSelect.value, 1);

      state.value = {'count': 2, 'data': 'changed'};
      expect(countSelect.value, 2);
    });

    test(
        'should not notify when source changes but selected value remains same',
        () {
      final state = {'count': 0, 'data': 'initial'}.lx;

      // Select only the 'count' property
      final countSelect = state.select((val) => val['count']);

      int notifications = 0;
      countSelect.addListener(() {
        notifications++;
      });

      expect(countSelect.value, 0);
      expect(notifications, 0);

      // Update 'data' but keep 'count' same
      state.value = {'count': 0, 'data': 'changed'};

      // Should NOT notify because count is still 0
      expect(notifications, 0);
      expect(countSelect.value, 0);

      // Update 'count'
      state.value = {'count': 1, 'data': 'changed'};

      // Should notify now
      expect(notifications, 1);
      expect(countSelect.value, 1);
    });

    test('should support nested objects', () {
      final user = {
        'profile': {'name': 'John', 'age': 30}
      }.lx;

      final nameSelect = user.select((val) => val['profile']!['name']);

      expect(nameSelect.value, 'John');

      // Update age, verify name doesn't trigger
      int nameNotifications = 0;
      nameSelect.addListener(() => nameNotifications++);

      user.value = {
        'profile': {'name': 'John', 'age': 31}
      };
      expect(nameNotifications, 0);
      expect(nameSelect.value, 'John');

      // Update name
      user.value = {
        'profile': {'name': 'Jane', 'age': 31}
      };
      expect(nameNotifications, 1);
      expect(nameSelect.value, 'Jane');
    });
  });
}
