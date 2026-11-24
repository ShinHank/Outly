class Participant {
  Participant({
    String? id,
    required this.name,
    required this.email,
    this.availableDates = const [],
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();
  final String id;
  final String name;
  final String email;
  final List<DateTime> availableDates;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'availableDates': availableDates
        .map((date) => date.toIso8601String())
        .toList(),
  };

  factory Participant.fromJson(Map<String, dynamic> json) => Participant(
    id: json['id'] as String?,
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    availableDates: ((json['availableDates'] as List?) ?? [])
        .map((date) => DateTime.parse(date as String))
        .toList(),
  );
}
