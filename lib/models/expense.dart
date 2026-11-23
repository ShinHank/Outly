import '../core/constants.dart';

class Expense {
  Expense({
    String? id,
    required this.title,
    required this.amount,
    required this.paidBy,
    required this.splitWith,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();
  final String id;
  final String title;
  final double amount;

  /// A participant id, or [hostId].
  final String paidBy;
  final List<String> splitWith;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'amount': amount,
    'paidBy': paidBy,
    'splitWith': splitWith,
  };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
    id: json['id'] as String?,
    title: json['title'] as String? ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    paidBy: json['paidBy'] as String? ?? hostId,
    splitWith: ((json['splitWith'] as List?) ?? []).cast<String>(),
  );
}

class Transfer {
  const Transfer(this.from, this.to, this.amount);
  final String from;
  final String to;
  final double amount;
}

/// Net balance per person: positive = is owed money, negative = owes money.
Map<String, double> balances(List<Expense> expenses) {
  final net = <String, double>{};
  for (final e in expenses) {
    if (e.splitWith.isEmpty) continue;
    final share = e.amount / e.splitWith.length;
    net[e.paidBy] = (net[e.paidBy] ?? 0) + e.amount;
    for (final id in e.splitWith) {
      net[id] = (net[id] ?? 0) - share;
    }
  }
  return net;
}

/// Fewest-ish payments that settle everyone up.
List<Transfer> settle(Map<String, double> net) {
  final debtors =
      net.entries
          .where((e) => e.value < -0.005)
          .map((e) => MapEntry(e.key, -e.value))
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
  final creditors = net.entries.where((e) => e.value > 0.005).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final debt = [for (final d in debtors) d.value];
  final credit = [for (final c in creditors) c.value];
  final out = <Transfer>[];
  var i = 0, j = 0;
  while (i < debtors.length && j < creditors.length) {
    final pay = debt[i] < credit[j] ? debt[i] : credit[j];
    if (pay > 0.005) out.add(Transfer(debtors[i].key, creditors[j].key, pay));
    debt[i] -= pay;
    credit[j] -= pay;
    if (debt[i] < 0.005) i++;
    if (credit[j] < 0.005) j++;
  }
  return out;
}
