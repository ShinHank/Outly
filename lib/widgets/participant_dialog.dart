import 'package:flutter/material.dart';

import '../models/participant.dart';

/// Add or edit a participant. Only a name is required.
///
/// The text controllers live in this widget's State so they are disposed
/// only after the dialog has fully left the screen.
class ParticipantDialog extends StatefulWidget {
  const ParticipantDialog({super.key, this.existing});
  final Participant? existing;

  @override
  State<ParticipantDialog> createState() => _ParticipantDialogState();
}

class _ParticipantDialogState extends State<ParticipantDialog> {
  late final TextEditingController name;
  late final TextEditingController email;
  String? nameError;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.existing?.name);
    email = TextEditingController(text: widget.existing?.email);
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    super.dispose();
  }

  void save() {
    final trimmed = name.text.trim();
    if (trimmed.isEmpty) {
      setState(() => nameError = 'Enter a name');
      return;
    }
    Navigator.pop(
      context,
      Participant(
        id: widget.existing?.id,
        name: trimmed,
        email: email.text.trim(),
        availableDates: widget.existing?.availableDates ?? const [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'Add participant' : 'Edit participant'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) {
            if (nameError != null) setState(() => nameError = null);
          },
          decoration: InputDecoration(labelText: 'Name', errorText: nameError),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email (optional)'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: save, child: const Text('Save')),
    ],
  );
}
