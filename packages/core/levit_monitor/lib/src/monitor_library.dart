/// Internal runtime library for `levit_monitor`.
///
/// Public consumers should import `package:levit_monitor/levit_monitor.dart`.
/// Inspector and DevTools integrations should import `package:levit_monitor/spi.dart`
/// or `package:levit_monitor/levit_monitor_protocol.dart`.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_dart_core/spi.dart';

import '../levit_monitor_protocol.dart';
import 'transports/websocket_connection.dart';
import 'transports/websocket_connector.dart';

export '../levit_monitor_protocol.dart';
export 'transports/websocket_connection.dart';

part 'core.dart';
part 'diagnostics.dart';
part 'event.dart';
part 'middleware.dart';
part 'snapshot.dart';
part 'transports/console_transport.dart';
part 'transports/interface.dart';
part 'transports/multi_transport.dart';
part 'transports/websocket_transport.dart';
