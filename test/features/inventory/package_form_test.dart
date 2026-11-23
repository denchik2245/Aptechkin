import 'package:aptechka/features/inventory/domain/package_form.dart';
import 'package:aptechka/features/inventory/domain/package_status.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/medicines/domain/stock_level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('stockModeFor', () {
    test('counts tablets, capsules, suppositories and ampoules', () {
      expect(stockModeFor('ТАБЛЕТКИ, ПОКРЫТЫЕ ОБОЛОЧКОЙ'), StockMode.count);
      expect(stockModeFor('Капсулы'), StockMode.count);
      expect(stockModeFor('Суппозитории ректальные'), StockMode.count);
      expect(stockModeFor('Раствор для инъекций в ампулах'), StockMode.count);
    });

    test('drops, syrups, sprays and creams go by level', () {
      expect(stockModeFor('Капли глазные'), StockMode.level);
      expect(stockModeFor('Суспензия для приема внутрь'), StockMode.level);
      expect(stockModeFor('Спрей назальный'), StockMode.level);
      expect(stockModeFor('Мазь'), StockMode.level);
      expect(stockModeFor('', unit: 'мл'), StockMode.level);
    });

    test('devices are not counted', () {
      expect(stockModeFor('Прибор'), StockMode.off);
      expect(stockModeFor('Термометр электронный'), StockMode.off);
    });

    test('every form option has a consistent mode', () {
      for (final option in drugFormOptions) {
        final mode = stockModeFor(option.form, unit: option.unit);
        expect(
          mode == StockMode.level,
          option.unit == 'флакон' || option.unit == 'тюбик',
          reason: option.label,
        );
      }
    });
  });

  test('units and containers', () {
    expect(countUnitFor('Таблетки'), 'таблеток');
    expect(countUnitFor('Свечи'), 'свечей');
    expect(countUnitFor('Что-то'), 'шт.');
    expect(containerFor('Крем'), 'тюбик');
    expect(containerFor('Сироп'), 'флакон');
    expect(openedSwitchLabel('Сироп'), 'Флакон уже вскрыт');
    expect(openedSwitchLabel('Гель'), 'Тюбик уже вскрыт');
    expect(openedSwitchLabel('Таблетки'), 'Упаковка уже вскрыта');
    expect(quantityLabel(20, 'таблеток'), '20 таблеток');
    expect(quantityLabel(1, 'шт.'), '1 шт.');
  });

  test('after-opening and month labels', () {
    expect(afterOpeningLabel(7), '7 дней');
    expect(afterOpeningLabel(30), '30 дней');
    expect(afterOpeningLabel(60), '2 месяца');
    expect(afterOpeningLabel(180), '6 месяцев');
    expect(afterOpeningLabel(365), '1 год');
    expect(monthYearLabel(DateTime(2028, 9, 30)), 'Сентябрь 2028');
    expect(endOfMonth(2028, 2), DateTime(2028, 2, 29));
    expect(endOfMonth(2028, 12), DateTime(2028, 12, 31));
  });

  test('validation follows «Форма / Ошибки заполнения»', () {
    final empty = validatePackageForm(
      name: ' ',
      form: '',
      expiryChoice: ExpiryChoice.date,
      expiry: null,
    );
    expect(empty.name, 'Введите название с упаковки');
    expect(empty.form, startsWith('Выберите форму'));
    expect(empty.expiry, 'Укажите срок или выберите «Укажу позже»');
    expect(
      validatePackageForm(
        name: 'Ибупрофен',
        form: 'Таблетки',
        expiryChoice: ExpiryChoice.later,
        expiry: null,
      ).isEmpty,
      isTrue,
    );
  });

  group('package fields', () {
    final now = DateTime(2026, 11, 17);
    Medicine package({
      bool noExpiry = false,
      StockLevel? level,
      bool tracksStock = true,
    }) => Medicine(
      id: 'p',
      name: 'Термометр',
      form: 'Прибор',
      dosage: '',
      quantity: 1,
      unit: 'шт.',
      location: '',
      noExpiry: noExpiry,
      stockLevel: level,
      tracksStock: tracksStock,
    );

    test('«Без срока годности» is fine, not unknown', () {
      final item = package(noExpiry: true);
      expect(item.statusAt(now), MedicineStatus.okay);
      expect(packageStatusLine(item, now).text, 'Без срока годности');
      expect(package().statusAt(now), MedicineStatus.unknown);
    });

    test('amount shows the level or «Без учёта»', () {
      expect(
        amountLabel(package(level: StockLevel.lessThanHalf)),
        'Меньше половины',
      );
      expect(amountLabel(package(tracksStock: false)), 'Без учёта');
    });

    test('new fields survive JSON', () {
      final restored = Medicine.fromJson(
        package(
          noExpiry: true,
          level: StockLevel.full,
          tracksStock: false,
        ).toJson(),
      );
      expect(restored.noExpiry, isTrue);
      expect(restored.stockLevel, StockLevel.full);
      expect(restored.tracksStock, isFalse);
      final legacy = Medicine.fromJson(
        package().toJson()
          ..remove('noExpiry')
          ..remove('stockLevel')
          ..remove('tracksStock'),
      );
      expect(legacy.noExpiry, isFalse);
      expect(legacy.stockLevel, isNull);
      expect(legacy.tracksStock, isTrue);
    });
  });
}
