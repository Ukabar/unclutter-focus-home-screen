import 'dart:async';

import 'package:flutter/services.dart';

abstract interface class LauncherRouteSource {
  Future<String?> takeInitialRoute();

  Stream<String> get routes;
}

class MethodChannelLauncherRouteSource implements LauncherRouteSource {
  MethodChannelLauncherRouteSource({
    MethodChannel channel = const MethodChannel(_channelName),
  }) : this._(channel);

  MethodChannelLauncherRouteSource._(this._channel) {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static const String _channelName =
      'com.zyverio.focuslauncher/launcher_routes';

  final MethodChannel _channel;
  final StreamController<String> _routes = StreamController<String>.broadcast();

  @override
  Future<String?> takeInitialRoute() async {
    try {
      return await _channel.invokeMethod<String>('takeInitialLauncherRoute');
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Stream<String> get routes => _routes.stream;

  Future<void> dispose() => _routes.close();

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'launcherRouteOpened') {
      return;
    }

    final Object? arguments = call.arguments;
    if (arguments is Map<Object?, Object?>) {
      final Object? route = arguments['route'];
      if (route is String && route.trim().isNotEmpty) {
        _routes.add(route);
      }
    }
  }
}
