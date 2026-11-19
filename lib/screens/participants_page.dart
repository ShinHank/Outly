import 'package:flutter/material.dart';

import '../models/participant.dart';
import '../services/local_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class ParticipantsPage extends StatelessWidget {
  const ParticipantsPage({
    super.key,
    required this.people,
    required this.store,
    required this.onChanged,
  });
  final List<Participant> people;
  final LocalStore store;
  final VoidCallback onChanged;

  Future<void> add(BuildContext context, [Participant? existing]) async {
    final name = TextEditingController(text: existing?.name);
    final email = TextEditingController(text: existing?.email);
    final result = await showDialog<Participant>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existing == null ? 'Add participant' : 'Edit participant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty || email.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(
                dialogContext,
                Participant(
                  id: existing?.id,
                  name: name.text.trim(),
                  email: email.text.trim(),
                  availableDates: existing?.availableDates ?? const [],
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    name.dispose();
    email.dispose();
    if (result != null) {
      final list = [...people];
      final index = list.indexWhere((person) => person.id == result.id);
      if (index == -1) {
        list.add(result);
      } else {
        list[index] = result;
      }
      await store.saveParticipants(list);
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Your people',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Add participant',
            onPressed: () => add(context),
            style: IconButton.styleFrom(
              backgroundColor: context.soft,
              foregroundColor: context.brandColor,
            ),
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      const SizedBox(height: 4),
      const HintText('Keep contacts here so they can be invited to any gala.'),
      const SizedBox(height: 18),
      if (people.isEmpty) const MessageCard('No participants yet.'),
      for (final person in people)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: CircleAvatar(
                backgroundColor: context.soft,
                child: Text(
                  person.name.isEmpty ? '?' : person.name[0].toUpperCase(),
                  style: TextStyle(
                    color: context.brandColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                person.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(person.email),
              trailing: IconButton(
                tooltip: 'Edit',
                onPressed: () => add(context, person),
                icon: const Icon(Icons.edit_outlined),
              ),
            ),
          ),
        ),
    ],
  );
}
