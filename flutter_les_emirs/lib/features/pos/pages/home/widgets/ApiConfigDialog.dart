import 'package:flutter/material.dart';

class ApiConfigDialog extends StatefulWidget {
  final String localUrl;
  final String cloudUrl;
  final void Function(String local, String cloud) onSave;
  const ApiConfigDialog({super.key, required this.localUrl, required this.cloudUrl, required this.onSave});

  @override
  State<ApiConfigDialog> createState() => _ApiConfigDialogState();
}

class _ApiConfigDialogState extends State<ApiConfigDialog> {
  late final TextEditingController _localCtrl;
  late final TextEditingController _cloudCtrl;

  @override
  void initState() {
    super.initState();
    _localCtrl = TextEditingController(text: widget.localUrl);
    _cloudCtrl = TextEditingController(text: widget.cloudUrl);
  }

  @override
  void dispose() {
    _localCtrl.dispose();
    _cloudCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configuration API (Local / Cloud)'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _localCtrl,
              decoration: const InputDecoration(labelText: 'API Local', hintText: 'http://localhost:3000', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cloudCtrl,
              decoration: const InputDecoration(labelText: 'API Cloud', hintText: 'https://ton-app.up.railway.app', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () {
            widget.onSave(_localCtrl.text.trim(), _cloudCtrl.text.trim());
            Navigator.of(context).pop();
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
