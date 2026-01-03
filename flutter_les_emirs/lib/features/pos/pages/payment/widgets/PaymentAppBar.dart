import 'package:flutter/material.dart';

class PaymentAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String tableNumber;
  final String? serverName;
  final VoidCallback onBack;

  const PaymentAppBar({
    super.key,
    required this.tableNumber,
    this.serverName,
    required this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(120);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final headerText = serverName != null && serverName!.isNotEmpty
        ? '${serverName!.toUpperCase()}: TABLE $tableNumber'
        : 'TABLE $tableNumber';
    
    // Calculer la taille de police adaptative selon la largeur de l'écran
    final fontSize = (screenWidth * 0.08).clamp(36.0, 72.0);
    
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF2C3E50),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: onBack,
          ),
          const SizedBox(width: 16),
          // 🆕 Overlay très visible : "Ali: Table 1" en très grand avec "ENCAISSEMENT" à côté
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🆕 "ALI: TABLE 1" et "ENCAISSEMENT" sur la même ligne
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      flex: 3,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          headerText,
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
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 🆕 "ENCAISSEMENT" à côté, aligné en bas
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        'ENCAISSEMENT',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

