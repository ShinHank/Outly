import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../models/expense.dart';
import '../models/participant.dart';

/// Add or edit one expense: what for, how much, who paid, and who shares it.
/// Only guests of the gala can pay or share.
///
/// Controllers live in this State so they are disposed after the dialog has
/// fully closed.
class ExpenseDialog extends StatefulWidget {
  const ExpenseDialog({super.key, required this.people, this.existing});
  final List<Participant> people;
  final Expense? existing;

  @override
  State<ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<ExpenseDialog> {
  late final TextEditingController title;
  late final TextEditingController amount;
  late String paidBy;
  late final Set<String> split;
  String? error;

  List<String> get ids => [for (final person in widget.people) person.id];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    title = TextEditingController(text: existing?.title);
    amount = TextEditingController(
      text: existing == null
          ? ''
          : existing.amount == existing.amount.roundToDouble()
          ? existing.amount.round().toString()
          : existing.amount.toStringAsFixed(2),
    );
    paidBy = existing != null && ids.contains(existing.paidBy)
        ? existing.paidBy
        : ids.first;
    split = {...(existing?.splitWith ?? ids).where(ids.contains)};
  }

  @override
  void dispose() {
    title.dispose();
    amount.dispose();
    super.dispose();
  }

  String nameOf(String id) {
    for (final person in widget.people) {
      if (person.id == id) return person.name.isEmpty ? 'Unnamed' : person.name;
    }
    return 'Someone';
  }

  void save() {
    final value = double.tryParse(amount.text.trim().replaceAll(',', ''));
    if (value == null || value <= 0) {
      setState(() => error = 'Enter an amount greater than $currency 0.');
      return;
    }
    if (split.isEmpty) {
      setState(() => error = 'Pick at least one person to split with.');
      return;
    }
    Navigator.pop(
      context,
      Expense(
        id: widget.existing?.id,
        title: title.text.trim().isEmpty ? 'Expense' : title.text.trim(),
        amount: value,
        paidBy: paidBy,
        splitWith: split.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = split.length == widget.people.length;
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add expense' : 'Edit expense'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'What for?'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '$currency ',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: paidBy,
              decoration: const InputDecoration(labelText: 'Paid by'),
              items: [
                for (final person in widget.people)
                  DropdownMenuItem(value: person.id, child: Text(nameOf(person.id))),
              ],
              onChanged: (value) => setState(() => paidBy = value ?? paidBy),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Split between',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    if (allSelected) {
                      split.clear();
                    } else {
                      split.addAll(ids);
                    }
                  }),
                  child: Text(allSelected ? 'Clear' : 'Select all'),
                ),
              ],
            ),
            for (final person in widget.people)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: split.contains(person.id),
                title: Text(nameOf(person.id)),
                onChanged: (value) => setState(() {
                  if (value == true) {
                    split.add(person.id);
                  } else {
                    split.remove(person.id);
                  }
                  error = null;
                }),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
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
}
