import 'package:flutter/material.dart';

/// Owns the input for the entire route, including its closing animation.
class PlayerTextPrompt extends StatefulWidget {
  const PlayerTextPrompt({
    super.key,
    required this.title,
    this.initial = '',
    this.pin = false,
  });
  final String title, initial;
  final bool pin;

  @override
  State<PlayerTextPrompt> createState() => _PlayerTextPromptState();
}

class _PlayerTextPromptState extends State<PlayerTextPrompt> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.title),
    content: SizedBox(
      width: 520,
      child: TextField(
        key: const ValueKey('dialog-input'),
        controller: _controller,
        autofocus: true,
        obscureText: widget.pin,
        maxLength: widget.pin ? 12 : 120,
        keyboardType: widget.pin ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: widget.pin ? 'Da 6 a 12 cifre' : 'Nome',
        ),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annulla'),
      ),
      TextButton(
        key: const ValueKey('dialog-confirm'),
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('Conferma'),
      ),
    ],
  );
}
