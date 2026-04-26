import 'package:flutter/material.dart';

import '../models/native_focus_event.dart';
import 'metric_card.dart';

class SignalGrid extends StatelessWidget {
  const SignalGrid({super.key, required this.focus, required this.compact});

  final NativeFocusEvent focus;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: compact ? 2 : 4,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: compact ? 2.15 : 2.35,
      children: [
        MetricCard(
          icon: Icons.input,
          label: 'Text Input',
          value: focus.isTextInput ? 'Yes' : 'No',
        ),
        MetricCard(
          icon: Icons.layers_outlined,
          label: 'Overlay',
          value: focus.overlayVisible ? 'Visible' : 'Hidden',
        ),
        MetricCard(
          icon: Icons.speed,
          label: 'Latency',
          value: '${focus.latencyMicros} us',
        ),
        MetricCard(
          icon: Icons.security,
          label: 'Password',
          value: focus.isPassword ? 'Protected' : 'No',
        ),
      ],
    );
  }
}
