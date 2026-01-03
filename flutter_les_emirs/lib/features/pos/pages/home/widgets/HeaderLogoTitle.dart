import 'package:flutter/material.dart';

class HeaderLogoTitle extends StatelessWidget {
  final String userName;
  const HeaderLogoTitle({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.point_of_sale, color: Color(0xFF3498DB), size: 32),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MACAISE APPLICATION D\'ENCAISSEMENT',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            Text(
              'Caissier $userName',
              style: const TextStyle(color: Color(0xFF3498DB), fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }
}


