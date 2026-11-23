import 'package:aptechka/app/app.dart';
import 'package:aptechka/app/router.dart';
import 'package:aptechka/app/routes.dart';
import 'package:aptechka/features/onboarding/data/onboarding_store.dart';
import 'package:aptechka/features/scanner/domain/scanned_code.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ScannedCode', () {
    test('EAN-13 and EAN-8 are barcodes without expiry', () {
      final ean13 = ScannedCode.parse('4600000000001')!;
      expect(ean13.gtin, '04600000000001');
      expect(ean13.kind, ScanKind.barcode);
      expect(ean13.expiry, isNull);
      expect(ScannedCode.parse('46012345')!.gtin, '00000046012345');
    });

    test('GS1 DataMatrix gives GTIN, expiry, batch and serial', () {
      const gs = '\u001d';
      final code = ScannedCode.parse(
        ']d201046070420031212145ABCDEFGHIJKL${gs}17280930${gs}10AB123',
      )!;
      expect(code.kind, ScanKind.dataMatrix);
      expect(code.gtin, '04607042003121');
      expect(code.serial, '45ABCDEFGHIJKL'.substring(0, 14));
      expect(code.expiry, DateTime(2028, 9, 30));
      expect(code.batch, 'AB123');
    });

    test('Russian marking without GS keeps the 13-char serial', () {
      final code = ScannedCode.parse(
        '01046070420031212112345ABCDEFGH91EE0792abcd',
      )!;
      expect(code.gtin, '04607042003121');
      expect(code.serial, '12345ABCDEFGH');
      expect(code.expiry, isNull);
    });

    test('day 00 means the last day of the month', () {
      final code = ScannedCode.parse('010460704200312117270200')!;
      expect(code.expiry, DateTime(2027, 2, 28));
    });

    test('garbage is rejected', () {
      expect(ScannedCode.parse('hello'), isNull);
      expect(ScannedCode.parse('17ABC'), isNull);
    });
  });

  group('scanner screen', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('first launch explains the camera before asking', (
      tester,
    ) async {
      await OnboardingStore.load();
      OnboardingStore.completed.value = null;
      appRouter.go(AppRoutes.inventory);
      await tester.pumpWidget(const ProviderScope(child: AptechkaApp()));
      await tester.pumpAndSettle();
      appRouter.push(AppRoutes.scanner);
      await tester.pumpAndSettle();

      expect(find.text('Сканирование'), findsOneWidget);
      expect(find.text('Сканируйте упаковку'), findsOneWidget);
      await tester.ensureVisible(find.text('Найти по названию'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Найти по названию'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Сканируйте упаковку'), findsNothing);
      expect(OnboardingStore.shouldExplainCamera, isTrue);
    });
  });
}
