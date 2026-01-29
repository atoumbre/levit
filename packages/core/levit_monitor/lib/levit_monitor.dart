/// A monitoring and diagnostics ecosystem for Levit applications.
///
/// This library provides the core infrastructure for capturing, filtering,
/// and transporting events from both dependency injection and reactive state
/// systems.
library levit_monitor;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:logger/logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

part 'src/core.dart';
part 'src/event.dart';
part 'src/middleware.dart';
part 'src/snapshot.dart';
part 'src/transports/console_transport.dart';
part 'src/transports/file_transport.dart';
part 'src/transports/interface.dart';
part 'src/transports/multi_transport.dart';
part 'src/transports/websocket_transport.dart';
