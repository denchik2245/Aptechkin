import 'package:aptechka/core/ui/stock_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Steps through the package form («Добавление · 2 · Форма упаковки»).
class PackageFormDriver {
  const PackageFormDriver(this.tester);
  final WidgetTester tester;

  Finder get _scrollable => find.byType(Scrollable).first;

  Future<void> reveal(Finder target, {double delta = 150}) async {
    if (target.evaluate().isEmpty) {
      // Scroll both ways: the target may sit above the current position.
      for (final step in [delta, -delta]) {
        final position = tester.state<ScrollableState>(_scrollable).position;
        for (var i = 0; target.evaluate().isEmpty && i < 40; i++) {
          position.jumpTo(
            (position.pixels + step).clamp(0, position.maxScrollExtent),
          );
          await tester.pumpAndSettle();
        }
        if (target.evaluate().isNotEmpty) break;
      }
    }
    await tester.ensureVisible(target.first);
    await tester.pumpAndSettle();
  }

  Future<void> tap(Finder target) async {
    await reveal(target);
    await tester.tap(target.first);
    await tester.pumpAndSettle();
  }

  Future<String> text(String key) async {
    await reveal(find.byKey(ValueKey(key)));
    return tester
        .widget<TextFormField>(find.byKey(ValueKey(key)))
        .controller!
        .text;
  }

  /// Scrolls to [target] and fails when it is not on the form.
  Future<void> expectShown(Finder target) async {
    await reveal(target);
    expect(target, findsWidgets);
  }

  Future<void> enter(String key, String value) async {
    await reveal(find.byKey(ValueKey(key)));
    await tester.enterText(find.byKey(ValueKey(key)), value);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  /// «20 таблеток» in the «stock control».
  Future<String> quantity() async {
    final counter = find.byKey(const ValueKey('package-quantity'));
    await reveal(counter);
    return tester.widget<StockCounter>(counter).value;
  }

  Future<void> plus([int times = 1]) async {
    for (var i = 0; i < times; i++) {
      await tap(find.byTooltip('Больше'));
    }
  }

  Future<void> minus([int times = 1]) async {
    for (var i = 0; i < times; i++) {
      await tap(find.byTooltip('Меньше'));
    }
  }

  Future<void> expiryLater() => tap(find.text('Укажу позже'));

  Future<void> chooseForm(String label) async {
    await tap(find.byKey(const ValueKey('drug-form-input')));
    final option = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text(label),
    );
    await tester.ensureVisible(option);
    await tester.pumpAndSettle();
    await tester.tap(option);
    await tester.pumpAndSettle();
  }

  /// Taps [label] inside the open bottom sheet.
  Future<void> tapInSheet(String label) async {
    final target = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text(label),
    );
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> addPlace(String name) async {
    await tap(find.text('+ Новое место'));
    final sheet = find.byType(BottomSheet);
    await tester.enterText(
      find.descendant(of: sheet, matching: find.byType(TextFormField)),
      name,
    );
    await tester.pumpAndSettle();
    await tapInSheet('Добавить место');
  }

  /// Saves and lets the «… добавлен в «Дом»» toast (4 s) go away.
  Future<void> save() async {
    await tap(find.byKey(const ValueKey('package-save')));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }
}
