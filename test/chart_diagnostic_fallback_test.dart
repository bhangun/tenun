import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  group('Tenun diagnostic fallbacks', () {
    test('options presets and copyWith compose cleanly', () {
      expect(TenunDiagnosticFallbackOptions.defaults.maxQuickFixes, 3);
      expect(TenunDiagnosticFallbackOptions.defaults.showDoctorSummary, isTrue);
      expect(
        TenunDiagnosticFallbackOptions.defaults.showValidationDetails,
        isTrue,
      );
      expect(TenunDiagnosticFallbackOptions.defaults.showErrorDetails, isTrue);
      expect(TenunDiagnosticFallbackOptions.defaults.showQuickFixes, isTrue);
      expect(TenunDiagnosticFallbackOptions.compact.maxQuickFixes, 1);
      expect(TenunDiagnosticFallbackOptions.quiet.showQuickFixes, isFalse);
      expect(
        TenunDiagnosticFallbackOptions.production.showDoctorSummary,
        isFalse,
      );
      expect(
        TenunDiagnosticFallbackOptions.production.showErrorDetails,
        isFalse,
      );
      expect(TenunDiagnosticFallbackOptions.production.maxQuickFixes, 0);

      final customized = TenunDiagnosticFallbackOptions.compact.copyWith(
        title: 'Review needed',
        message: 'Fix before release.',
        showDoctorSummary: false,
        showValidationDetails: false,
        showErrorDetails: false,
        showQuickFixes: false,
      );

      expect(customized.title, 'Review needed');
      expect(customized.message, 'Fix before release.');
      expect(customized.maxQuickFixes, 1);
      expect(customized.showDoctorSummary, isFalse);
      expect(customized.showValidationDetails, isFalse);
      expect(customized.showErrorDetails, isFalse);
      expect(customized.showQuickFixes, isFalse);

      final cleared = customized.copyWith(clearTitle: true, clearMessage: true);

      expect(cleared.title, isNull);
      expect(cleared.message, isNull);
      expect(cleared.maxQuickFixes, 1);
    });

    test('options use value equality for stable rebuild comparisons', () {
      const first = TenunDiagnosticFallbackOptions(
        title: 'Review',
        message: 'Fix payload',
        showQuickFixes: false,
        maxQuickFixes: 1,
      );
      const second = TenunDiagnosticFallbackOptions(
        title: 'Review',
        message: 'Fix payload',
        showQuickFixes: false,
        maxQuickFixes: 1,
      );
      const changed = TenunDiagnosticFallbackOptions(
        title: 'Review',
        message: 'Fix payload',
        showQuickFixes: false,
        maxQuickFixes: 2,
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(changed));
      expect(first.toString(), contains('maxQuickFixes: 1'));
    });

    test('options serialize stable diagnostics metadata', () {
      final options = TenunDiagnosticFallbackOptions.quiet.copyWith(
        title: 'Review needed',
        message: 'Fix before release.',
        detailMessage: 'Switch blocked.',
        footerChildren: const [Text('Open diagnostics')],
        showDoctorSummary: false,
        showValidationDetails: false,
        maxQuickFixes: 1,
      );

      expect(options.toJson(), {
        'title': 'Review needed',
        'message': 'Fix before release.',
        'detailMessage': 'Switch blocked.',
        'footerChildCount': 1,
        'showDoctorSummary': false,
        'showValidationDetails': false,
        'showErrorDetails': true,
        'showQuickFixes': false,
        'maxQuickFixes': 1,
      });
      expect(
        TenunDiagnosticFallbackOptions.defaults.toJson(),
        containsPair('footerChildCount', 0),
      );
    });

    test('options parse from JSON maps and preset names', () {
      final parsed = TenunDiagnosticFallbackOptions.fromJson({
        'preset': 'compact',
        'title': 'Review payload',
        'message': 'Fix this chart before release.',
        'detailMessage': 'Renderer rejected the payload.',
        'showDoctorSummary': 'false',
        'showValidationDetails': false,
        'showErrorDetails': 0,
        'showQuickFixes': 'no',
        'maxQuickFixes': '2',
      });

      expect(parsed.title, 'Review payload');
      expect(parsed.message, 'Fix this chart before release.');
      expect(parsed.detailMessage, 'Renderer rejected the payload.');
      expect(parsed.showDoctorSummary, isFalse);
      expect(parsed.showValidationDetails, isFalse);
      expect(parsed.showErrorDetails, isFalse);
      expect(parsed.showQuickFixes, isFalse);
      expect(parsed.maxQuickFixes, 2);

      final production = TenunDiagnosticFallbackOptions.fromJson('production');
      expect(production.showDoctorSummary, isFalse);
      expect(production.showValidationDetails, isFalse);
      expect(production.showErrorDetails, isFalse);
      expect(production.showQuickFixes, isFalse);

      const fallback = TenunDiagnosticFallbackOptions(
        showQuickFixes: true,
        maxQuickFixes: 5,
      );
      final unknownPreset = TenunDiagnosticFallbackOptions.fromJson({
        'preset': 'unknown',
        'showQuickFixes': 'false',
        'maxQuickFixes': -1,
      }, fallback: fallback);

      expect(unknownPreset.showQuickFixes, isFalse);
      expect(unknownPreset.maxQuickFixes, 5);
      expect(
        TenunDiagnosticFallbackOptions.fromJson(null, fallback: fallback),
        fallback,
      );

      final resolved = TenunDiagnosticFallbackOptions.resolve({
        'type': 'line',
        'diagnostics': {
          'fallbackOptions': {
            'preset': 'production',
            'title': 'Chart unavailable',
            'message': 'Use another dataset.',
          },
        },
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      });

      expect(resolved.title, 'Chart unavailable');
      expect(resolved.message, 'Use another dataset.');
      expect(resolved.showDoctorSummary, isFalse);
      expect(resolved.showValidationDetails, isFalse);
      expect(resolved.showErrorDetails, isFalse);
    });

    testWidgets('validation fallback supports contextual copy and footer', (
      tester,
    ) async {
      const payload = <String, dynamic>{
        'type': 'line',
        'sampling': {'enabled': 'yes'},
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      };
      final validation = ChartConfigValidator.validateJsonPayload(payload);

      await tester.pumpWidget(
        MaterialApp(
          home: TenunValidationReportFallback(
            result: validation,
            rawPayload: payload,
            validationReportMaxIssues: 2,
            title: 'Dataset needs attention',
            message: 'Review the payload before publishing.',
            footerChildren: const [Text('Open diagnostics')],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dataset needs attention'), findsOneWidget);
      expect(
        find.text('Review the payload before publishing.'),
        findsOneWidget,
      );
      expect(find.textContaining('Doctor: repairable'), findsOneWidget);
      expect(find.text('Open diagnostics'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('validation fallback can limit or hide quick fixes', (
      tester,
    ) async {
      const payload = <String, dynamic>{
        'type': 'line',
        'sampling': {'enabled': 'yes'},
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      };
      final validation = ChartConfigValidator.validateJsonPayload(payload);

      await tester.pumpWidget(
        MaterialApp(
          home: TenunValidationReportFallback(
            result: validation,
            rawPayload: payload,
            validationReportMaxIssues: 2,
            maxQuickFixes: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quick fixes:'), findsOneWidget);
      expect(
        find.textContaining('Enable autoNormalizePayload'),
        findsOneWidget,
      );
      expect(find.textContaining('Apply normalization'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          home: TenunValidationReportFallback(
            result: validation,
            rawPayload: payload,
            validationReportMaxIssues: 2,
            showQuickFixes: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quick fixes:'), findsNothing);
      expect(find.textContaining('Enable autoNormalizePayload'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('validation fallback can hide doctor and issue details', (
      tester,
    ) async {
      const payload = <String, dynamic>{
        'type': 'line',
        'sampling': {'enabled': 'yes'},
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      };
      final validation = ChartConfigValidator.validateJsonPayload(payload);

      await tester.pumpWidget(
        MaterialApp(
          home: TenunValidationReportFallback(
            result: validation,
            rawPayload: payload,
            validationReportMaxIssues: 2,
            options: TenunDiagnosticFallbackOptions.quiet.copyWith(
              message: 'Payload is blocked.',
              showDoctorSummary: false,
              showValidationDetails: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Payload is blocked.'), findsOneWidget);
      expect(find.textContaining('Doctor:'), findsNothing);
      expect(find.textContaining('Invalid line chart payload'), findsNothing);
      expect(find.textContaining('sampling.enabled'), findsNothing);
      expect(find.text('Quick fixes:'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('render fallback can hide raw errors while keeping context', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TenunRenderErrorFallback(
            error: StateError('renderer exploded'),
            options: TenunDiagnosticFallbackOptions.quiet.copyWith(
              title: 'Render blocked',
              message: 'Use a supported chart bundle.',
              showErrorDetails: false,
              footerChildren: const [Text('Open logs')],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Render blocked'), findsOneWidget);
      expect(find.text('Use a supported chart bundle.'), findsOneWidget);
      expect(find.text('Open logs'), findsOneWidget);
      expect(find.textContaining('renderer exploded'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
