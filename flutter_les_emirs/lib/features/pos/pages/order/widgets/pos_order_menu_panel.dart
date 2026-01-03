import 'package:flutter/material.dart';
import '../../../widgets/pos_menu_grid.dart';

class PosOrderMenuPanel extends StatelessWidget {
  final bool loadingMenu;
  final Map<String, dynamic>? menu;
  final Function(Map<String, dynamic>) onItemSelected;

  const PosOrderMenuPanel({
    super.key,
    required this.loadingMenu,
    required this.menu,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 3,
      child: loadingMenu
          ? const Center(child: CircularProgressIndicator())
          : menu != null
              ? PosMenuGrid(
                  menu: menu!,
                  onItemSelected: onItemSelected,
                )
              : const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 48, color: Colors.red),
                      SizedBox(height: 16),
                      Text('Erreur de chargement du menu'),
                      SizedBox(height: 8),
                      Text('Vérifiez la connexion au serveur'),
                    ],
                  ),
                ),
    );
  }
}

