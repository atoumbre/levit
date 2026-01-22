import 'package:levit_scope/levit_scope.dart';

class Locator {
  static LevitScope root = LevitScope.root();
}

// A simple service
class DatabaseService extends LevitScopeDisposable {
  bool connected = false;

  @override
  void onInit() {
    print('DatabaseService: Initializing...');
    connected = true;
  }

  @override
  void onClose() {
    print('DatabaseService: Closing...');
    connected = false;
  }

  void query(String sql) {
    if (!connected) throw Exception('Database not connected');
    print('DatabaseService: Executing "$sql"');
  }
}

// A dependent service
class UserRepository {
  // Dependencies are resolved seamlessly
  final db = Locator.root.find<DatabaseService>();

  void findUser(int id) {
    db.query('SELECT * FROM users WHERE id = $id');
  }
}

void main() {
  // 1. Register dependencies
  print('--- Registering ---');
  Locator.root.put(() => DatabaseService());
  Locator.root.lazyPut(() => UserRepository());

  // 2. Use dependencies
  print('\n--- Resolving ---');
  final repo = Locator.root.find<UserRepository>();
  repo.findUser(42);

  // 3. Clean up
  print('\n--- Cleaning up ---');
  Locator.root.reset(); // Disposes DatabaseService

  try {
    repo.findUser(42);
  } catch (e) {
    print('Error: $e');
  }
}
