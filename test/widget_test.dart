import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:master_dnd/main.dart';

void main() {
  testWidgets('Master DND app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MasterDndApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
