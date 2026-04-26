import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/native_focus_event.dart';

class NativeFocusService {
  const NativeFocusService();

  static const MethodChannel _methods = MethodChannel(
    'win_text_overlay_demo/native',
  );
  static const EventChannel _events = EventChannel(
    'win_text_overlay_demo/focus_events',
  );

  bool get isSupported {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  }

  Stream<NativeFocusEvent> get events {
    return _events
        .receiveBroadcastStream()
        .where((event) {
          return event is Map;
        })
        .map((event) {
          return NativeFocusEvent.fromMap(event as Map<dynamic, dynamic>);
        });
  }

  Future<bool> start() async {
    return await _methods.invokeMethod<bool>('start') ?? false;
  }

  Future<void> stop() async {
    await _methods.invokeMethod<bool>('stop');
  }

  Future<NativeFocusEvent?> refresh() async {
    final Object? event = await _methods.invokeMethod<Object>('refresh');
    if (event is Map) {
      return NativeFocusEvent.fromMap(event);
    }
    return null;
  }
}
