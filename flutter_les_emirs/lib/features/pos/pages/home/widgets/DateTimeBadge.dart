import 'package:flutter/material.dart';

class DateTimeBadge extends StatelessWidget {
  const DateTimeBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final date = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          date,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          time,
          style: const TextStyle(color: Color(0xFF3498DB), fontSize: 14),
        ),
      ],
    );
  }
}


