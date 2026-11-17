import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outly/main.dart';

void main() {
  testWidgets('Outly opens the outing dashboard', (tester) async {
    await tester.pumpWidget(const OutlyApp());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
