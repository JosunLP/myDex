import 'package:flutter/material.dart';

/// Simple input dialog. The controller lives as long as the dialog (including
/// the closing animation).
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String confirm,
  required String cancel,
  bool obscure = false,
}) => showDialog<String>(
  context: context,
  builder: (_) => _TextInputDialog(
    title: title,
    label: label,
    confirm: confirm,
    cancel: cancel,
    obscure: obscure,
  ),
);

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.label,
    required this.confirm,
    required this.cancel,
    required this.obscure,
  });

  final String title;
  final String label;
  final String confirm;
  final String cancel;
  final bool obscure;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      obscureText: widget.obscure,
      decoration: InputDecoration(labelText: widget.label),
      onSubmitted: (v) => Navigator.pop(context, v),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(widget.cancel),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: Text(widget.confirm),
      ),
    ],
  );
}
