import 'package:flutter/material.dart';

import '../models/native_focus_event.dart';
import 'detail_card.dart';

class DetailGrid extends StatelessWidget {
  const DetailGrid({super.key, required this.focus, required this.compact});

  final NativeFocusEvent focus;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: compact ? 1 : 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: compact ? 2.5 : 1.25,
      children: [
        DetailCard(
          title: 'Focused App',
          rows: [
            DetailRow('Process', focus.processName),
            DetailRow('Window', focus.appTitle),
            DetailRow('Class', focus.windowClass),
            DetailRow('HWND', focus.hwnd),
          ],
        ),
        DetailCard(
          title: 'Focused Control',
          rows: [
            DetailRow('Name', focus.controlName),
            DetailRow('Type', focus.controlType),
            DetailRow('Element Rect', focus.elementRect.label),
            DetailRow('Caret Rect', focus.caretRect.label),
          ],
        ),
        DetailCard(
          title: 'Text Extraction',
          rows: [
            DetailRow('Value', focus.isPassword ? 'Protected' : focus.value),
          ],
        ),
      ],
    );
  }
}
