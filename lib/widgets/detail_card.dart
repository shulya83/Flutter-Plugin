import 'package:flutter/material.dart';

class DetailCard extends StatelessWidget {
  const DetailCard({super.key, required this.title, required this.rows});

  final String title;
  final List<DetailRow> rows;

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

class DetailRow {
  const DetailRow(this.label, this.value);

  final String label;
  final String value;
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.row});

  final DetailRow row;

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
