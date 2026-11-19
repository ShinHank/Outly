import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/gala.dart';
import '../models/participant.dart';

class LocalStore {
  Future<List<Gala>> galas() async {
    final prefs = await SharedPreferences.getInstance();
    return (jsonDecode(prefs.getString('galas') ?? '[]') as List)
        .map((item) => Gala.fromJson((item as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<Participant>> participants() async {
    final prefs = await SharedPreferences.getInstance();
    return (jsonDecode(prefs.getString('participants') ?? '[]') as List)
        .map(
          (item) => Participant.fromJson((item as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  Future<void> saveGalas(List<Gala> items) async =>
      (await SharedPreferences.getInstance()).setString(
        'galas',
        jsonEncode(items.map((item) => item.toJson()).toList()),
      );

  Future<void> saveParticipants(List<Participant> items) async =>
      (await SharedPreferences.getInstance()).setString(
        'participants',
        jsonEncode(items.map((item) => item.toJson()).toList()),
      );
}
