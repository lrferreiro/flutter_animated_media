import 'package:flutter/material.dart';
import 'package:flutter_animated_media/flutter_animated_media.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:animated_media_example/main.dart';

void main() {
  testWidgets(
    'gallery exposes search and a custom catalog without chat concepts',
    (tester) async {
      await tester.pumpWidget(const AnimatedMediaExample());
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Custom catalog'), findsOneWidget);
      expect(find.byType(AnimatedMediaPicker), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'nonexistent');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text('No matching media'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
