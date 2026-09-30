import 'package:class_lms/core/theme/app_theme.dart';
import 'package:class_lms/core/widgets/app_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty states remain readable with large text in both themes', (
    tester,
  ) async {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: EmptyState(
                  title: 'No quizzes yet',
                  message: 'Your upcoming quizzes will appear here.',
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('No quizzes yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
