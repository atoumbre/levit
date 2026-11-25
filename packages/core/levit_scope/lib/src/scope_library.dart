/// Internal runtime library for `levit_scope`.
///
/// Public consumers should import `package:levit_scope/levit_scope.dart`.
/// Framework and tooling integrations should import `package:levit_scope/spi.dart`.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:developer' as dev;

part 'core.dart';
part 'description.dart';
part 'middleware.dart';
part 'global_accessor.dart';
