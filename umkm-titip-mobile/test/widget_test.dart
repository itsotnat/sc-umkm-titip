import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umkm_titip/widgets/status_badge.dart';

void main() {
  testWidgets('StatusBadge menampilkan label status', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: StatusBadge(label: 'Lunas'))));
    expect(find.text('Lunas'), findsOneWidget);
  });
}
