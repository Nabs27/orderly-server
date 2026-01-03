import 'package:flutter/material.dart';

class ServerSelectionDialog extends StatelessWidget {
  final List<Map<String, dynamic>> servers;
  final Function(String server) onServerSelected;

  const ServerSelectionDialog({
    super.key,
    required this.servers,
    required this.onServerSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sélectionner un serveur'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: servers.map((server) => 
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.teal,
              child: Text(
                (server['name'] as String)[0],
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(server['name'] as String),
            subtitle: Text(server['role'] as String? ?? 'Serveur'),
            onTap: () {
              Navigator.of(context).pop();
              onServerSelected(server['name'] as String);
            },
          ),
        ).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}

