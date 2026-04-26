import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/native_focus_event.dart';
import '../services/native_focus_service.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/detail_grid.dart';
import '../widgets/local_input_probe.dart';
import '../widgets/signal_grid.dart';

class FocusOverlayDashboard extends StatefulWidget {
  const FocusOverlayDashboard({super.key});

  @override
  State<FocusOverlayDashboard> createState() => _FocusOverlayDashboardState();
}

class _FocusOverlayDashboardState extends State<FocusOverlayDashboard> {
  static const NativeFocusService _service = NativeFocusService();

  StreamSubscription<NativeFocusEvent>? _subscription;
  NativeFocusEvent _focus = NativeFocusEvent.empty();
  bool _nativeStarted = false;
  String _status = 'Waiting for native tracker';

  @override
  void initState() {
    super.initState();
    if (_service.isSupported) {
      _subscription = _service.events.listen(
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
    if (_service.isSupported) {
      unawaited(_service.stop());
    }
    super.dispose();
  }

  Future<void> _startNative() async {
    try {
      final bool started = await _service.start();
      if (!mounted) {
        return;
      }
      setState(() {
        _nativeStarted = started;
        _status = started ? 'Native tracker active' : 'Native tracker failed';
      });
    } on MissingPluginException {
      _setNativeError('Native channel unavailable');
    } on PlatformException catch (error) {
      _setNativeError(error.message ?? error.code);
    }
  }

  void _handleNativeEvent(NativeFocusEvent event) {
    setState(() {
      _focus = event;
      _status = event.isTextInput
          ? 'Text input detected'
          : 'Focused control is not text input';
    });
  }

  void _handleNativeError(Object error) {
    _setNativeError(error.toString());
  }

  void _setNativeError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _nativeStarted = false;
      _status = message;
    });
  }

  Future<void> _refresh() async {
    final NativeFocusEvent? event = await _service.refresh();
    if (event == null || !mounted) {
      return;
    }
    setState(() {
      _focus = event;
    });
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
                  DashboardHeader(
                    active: _nativeStarted,
                    status: _status,
                    onRefresh: _service.isSupported ? _refresh : null,
                  ),
                  const SizedBox(height: 18),
                  SignalGrid(focus: _focus, compact: compact),
                  const SizedBox(height: 18),
                  DetailGrid(focus: _focus, compact: compact),
                  const SizedBox(height: 18),
                  const LocalInputProbe(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
