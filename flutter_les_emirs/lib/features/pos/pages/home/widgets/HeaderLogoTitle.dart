import 'package:flutter/material.dart';

class HeaderLogoTitle extends StatelessWidget {
  final String userName;
  const HeaderLogoTitle({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Taille de police adaptative similaire à PaymentAppBar
    final fontSize = (screenWidth * 0.08).clamp(36.0, 72.0);
    
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        userName.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: 2.0,
          height: 1.1,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}


