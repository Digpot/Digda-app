import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digda/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DigdaApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
