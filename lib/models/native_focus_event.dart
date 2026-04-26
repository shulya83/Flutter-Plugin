class NativeFocusEvent {
  const NativeFocusEvent({
    required this.appTitle,
    required this.processName,
    required this.windowClass,
    required this.controlName,
    required this.controlType,
    required this.value,
    required this.hwnd,
    required this.elementRect,
    required this.caretRect,
    required this.isPassword,
    required this.isTextInput,
    required this.overlayVisible,
    required this.latencyMicros,
  });

  factory NativeFocusEvent.empty() {
    return const NativeFocusEvent(
      appTitle: '',
      processName: '',
      windowClass: '',
      controlName: '',
      controlType: '',
      value: '',
      hwnd: '',
      elementRect: NativeRect.empty(),
      caretRect: NativeRect.empty(),
      isPassword: false,
      isTextInput: false,
      overlayVisible: false,
      latencyMicros: 0,
    );
  }

  factory NativeFocusEvent.fromMap(Map<dynamic, dynamic> map) {
    return NativeFocusEvent(
      appTitle: _readString(map, 'appTitle'),
      processName: _readString(map, 'processName'),
      windowClass: _readString(map, 'windowClass'),
      controlName: _readString(map, 'controlName'),
      controlType: _readString(map, 'controlType'),
      value: _readString(map, 'value'),
      hwnd: _readString(map, 'hwnd'),
      elementRect: NativeRect.fromMap(map['elementRect']),
      caretRect: NativeRect.fromMap(map['caretRect']),
      isPassword: map['isPassword'] == true,
      isTextInput: map['isTextInput'] == true,
      overlayVisible: map['overlayVisible'] == true,
      latencyMicros: _readInt(map, 'latencyMicros'),
    );
  }

  final String appTitle;
  final String processName;
  final String windowClass;
  final String controlName;
  final String controlType;
  final String value;
  final String hwnd;
  final NativeRect elementRect;
  final NativeRect caretRect;
  final bool isPassword;
  final bool isTextInput;
  final bool overlayVisible;
  final int latencyMicros;
}

class NativeRect {
  const NativeRect({
    required this.valid,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  const NativeRect.empty()
    : valid = false,
      left = 0,
      top = 0,
      right = 0,
      bottom = 0;

  factory NativeRect.fromMap(Object? raw) {
    if (raw is! Map) {
      return const NativeRect.empty();
    }
    return NativeRect(
      valid: raw['valid'] == true,
      left: _readInt(raw, 'left'),
      top: _readInt(raw, 'top'),
      right: _readInt(raw, 'right'),
      bottom: _readInt(raw, 'bottom'),
    );
  }

  final bool valid;
  final int left;
  final int top;
  final int right;
  final int bottom;

  String get label {
    if (!valid) {
      return 'Unavailable';
    }
    return '$left, $top, $right, $bottom';
  }
}

String _readString(Map<dynamic, dynamic> map, String key) {
  final Object? value = map[key];
  return value is String ? value : '';
}

int _readInt(Map<dynamic, dynamic> map, String key) {
  final Object? value = map[key];
  return value is num ? value.toInt() : 0;
}
