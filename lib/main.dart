import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Windows Text Overlay Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E7A5F),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F7F9),
        useMaterial3: true,
      ),
      home: const FocusOverlayDashboard(),
    );
  }
}

class FocusOverlayDashboard extends StatefulWidget {
  const FocusOverlayDashboard({super.key});

  @override
  State<FocusOverlayDashboard> createState() => _FocusOverlayDashboardState();
}

class _FocusOverlayDashboardState extends State<FocusOverlayDashboard> {
  static const MethodChannel _methods = MethodChannel(
    'win_text_overlay_demo/native',
  );
  static const EventChannel _events = EventChannel(
    'win_text_overlay_demo/focus_events',
  );

  StreamSubscription<dynamic>? _subscription;
  NativeFocusEvent _focus = NativeFocusEvent.empty();
  bool _nativeStarted = false;
  String _status = 'Waiting for native tracker';

  bool get _canUseNative =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  void initState() {
    super.initState();
    if (_canUseNative) {
      _subscription = _events.receiveBroadcastStream().listen(
        _handleNativeEvent,
        onError: _handleNativeError,
      );
      unawaited(_startNative());
    } else {
      _status = 'Windows desktop target required';
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    if (_canUseNative) {
      unawaited(_methods.invokeMethod<bool>('stop'));
    }
    super.dispose();
  }

  Future<void> _startNative() async {
    try {
      final bool started = await _methods.invokeMethod<bool>('start') ?? false;
      if (!mounted) {
        return;
      }
      setState(() {
        _nativeStarted = started;
        _status = started ? 'Native tracker active' : 'Native tracker failed';
      });
    } on MissingPluginException {
      if (!mounted) {
        return;
      }
      setState(() {
        _nativeStarted = false;
        _status = 'Native channel unavailable';
      });
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _nativeStarted = false;
        _status = error.message ?? error.code;
      });
    }
  }

  void _handleNativeEvent(dynamic event) {
    if (event is! Map) {
      return;
    }
    setState(() {
      _focus = NativeFocusEvent.fromMap(event);
      _status = _focus.isTextInput
          ? 'Text input detected'
          : 'Focused control is not text input';
    });
  }

  void _handleNativeError(Object error) {
    setState(() {
      _nativeStarted = false;
      _status = error.toString();
    });
  }

  Future<void> _refresh() async {
    final Object? event = await _methods.invokeMethod<Object>('refresh');
    if (event is Map && mounted) {
      setState(() {
        _focus = NativeFocusEvent.fromMap(event);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool compact = constraints.maxWidth < 840;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    active: _nativeStarted,
                    status: _status,
                    onRefresh: _canUseNative ? _refresh : null,
                  ),
                  const SizedBox(height: 18),
                  _SignalGrid(focus: _focus, compact: compact),
                  const SizedBox(height: 18),
                  _DetailGrid(focus: _focus, compact: compact),
                  const SizedBox(height: 18),
                  const _LocalInputProbe(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

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

class _Header extends StatelessWidget {
  const _Header({
    required this.active,
    required this.status,
    required this.onRefresh,
  });

  final bool active;
  final String status;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Windows Text Overlay Demo',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
              _StatusPill(active: active, label: status),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Refresh',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}

class _SignalGrid extends StatelessWidget {
  const _SignalGrid({required this.focus, required this.compact});

  final NativeFocusEvent focus;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = [
      _MetricCard(
        icon: Icons.input,
        label: 'Text Input',
        value: focus.isTextInput ? 'Yes' : 'No',
      ),
      _MetricCard(
        icon: Icons.layers_outlined,
        label: 'Overlay',
        value: focus.overlayVisible ? 'Visible' : 'Hidden',
      ),
      _MetricCard(
        icon: Icons.speed,
        label: 'Latency',
        value: '${focus.latencyMicros} us',
      ),
      _MetricCard(
        icon: Icons.security,
        label: 'Password',
        value: focus.isPassword ? 'Protected' : 'No',
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: compact ? 2 : 4,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: compact ? 2.15 : 2.35,
      children: cards,
    );
  }
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.focus, required this.compact});

  final NativeFocusEvent focus;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final List<Widget> details = [
      _DetailCard(
        title: 'Focused App',
        rows: [
          _DetailRow('Process', focus.processName),
          _DetailRow('Window', focus.appTitle),
          _DetailRow('Class', focus.windowClass),
          _DetailRow('HWND', focus.hwnd),
        ],
      ),
      _DetailCard(
        title: 'Focused Control',
        rows: [
          _DetailRow('Name', focus.controlName),
          _DetailRow('Type', focus.controlType),
          _DetailRow('Element Rect', focus.elementRect.label),
          _DetailRow('Caret Rect', focus.caretRect.label),
        ],
      ),
      _DetailCard(
        title: 'Text Extraction',
        rows: [
          _DetailRow('Value', focus.isPassword ? 'Protected' : focus.value),
        ],
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: compact ? 1 : 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: compact ? 2.5 : 1.25,
      children: details,
    );
  }
}

class _LocalInputProbe extends StatelessWidget {
  const _LocalInputProbe();

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        labelText: 'Local text input',
        prefixIcon: const Icon(Icons.keyboard_alt_outlined),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD6DEE6)),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE5EC)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF1E7A5F), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF607080),
                      fontSize: 12,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF17202A),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.rows});

  final String title;
  final List<_DetailRow> rows;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE5EC)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 12),
            for (final row in rows) _DetailLine(row: row),
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.row});

  final _DetailRow row;

  @override
  Widget build(BuildContext context) {
    final String value = row.value.isEmpty ? 'Unavailable' : row.value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              row.label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF607080),
                fontSize: 12,
                letterSpacing: 0,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF17202A),
                fontSize: 13,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active, required this.label});

  final bool active;
  final String label;

  @override
  Widget build(BuildContext context) {
    final Color color = active
        ? const Color(0xFF1E7A5F)
        : const Color(0xFF8A5A18);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? Icons.check_circle : Icons.info,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
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
