import 'package:levit_dart_core/levit_dart_core.dart';

// --- PATTERN 1: Functional State (LevitStore) ---
// Best for stateless logic, simple shared atoms, or derived global state.
final settingsStore = LevitStore((ref) {
  final theme = ref.autoDispose('light'.lx);

  // React to changes within the functional block
  ref.onDispose(() => print('SettingsState: Cleaned up resources'));

  return theme;
});

// A derived functional state that watches settingsState
final themeLabelStore = LevitStore((ref) {
  final theme = settingsStore.find();
  return 'Theme is: ${theme.value.toUpperCase()}';
});

// --- PATTERN 2: Class-based Logic (LevitController) ---
// Best for complex lifecycle management, private methods, and heavy side-effects.
class AuthController extends LevitController {
  final isAuthenticated = false.lx;
  final username = 'Guest'.lx;

  @override
  void onInit() {
    super.onInit();
    print('AuthController: Initialized');

    // We can also watch functional state from a controller!
    final theme = settingsStore.find();
    autoDispose(LxWorker(theme, (val) {
      print('AuthController: Detected theme change to $val');
    }));
  }

  void login(String name) {
    username.value = name;
    isAuthenticated.value = true;
  }

  void logout() {
    username.value = 'Guest';
    isAuthenticated.value = false;
  }
}

void main() async {
  print('=== Levit State Management Demo ===\n');

  // --- Using Functional State ---
  final theme = settingsStore.find();
  final label = themeLabelStore.find();

  print('Initial Theme: ${theme.value}');
  print('Initial Label: $label');

  // --- Using Class-based Logic ---
  final auth = Levit.put(() => AuthController());

  print('User: ${auth.username.value} (Auth: ${auth.isAuthenticated.value})');

  // Interacting
  print('\n--- Performing Mutations ---');
  auth.login('Alice');
  theme.value = 'dark';

  print('Label updated automatically: ${themeLabelStore.find()}');
  print(
      'User updated: ${auth.username.value} (Auth: ${auth.isAuthenticated.value})');

  // Cleanup
  print('\n--- Cleaning Up ---');
  Levit.reset(); // Disposes everything in root scope
}
