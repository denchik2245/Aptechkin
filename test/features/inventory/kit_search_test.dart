import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/kit_search.dart';
import 'package:aptechka/features/inventory/domain/pharmacy.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/medicines/domain/medicine_purpose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 10);

  Pharmacy kit(String id, String name, {bool shared = false}) => Pharmacy(
    id: id,
    name: name,
    ownerLabel: shared ? 'Ольга' : 'Вы',
    isShared: shared,
    canEdit: true,
  );

  Medicine package(
    String id,
    String name, {
    String kit = 'home',
    String place = 'Верхняя полка',
    String? ingredient,
    int quantity = 4,
    DateTime? expiry,
    MedicinePurpose? purpose,
  }) => Medicine(
    id: id,
    pharmacyId: kit,
    name: name,
    activeIngredient: ingredient,
    form: 'Таблетки',
    dosage: '200 мг',
    quantity: quantity,
    unit: 'таблеток',
    location: place,
    expiryDate: expiry,
    purposes: [?purpose],
  );

  AppState state(List<Medicine> medicines, {String selected = 'home'}) =>
      AppState(
        pharmacies: [
          kit('home', 'Дом'),
          kit('mom', 'Аптечка мамы', shared: true),
          kit('dacha', 'Дача'),
          kit('car', 'Машина'),
        ],
        selectedPharmacyId: selected,
        medicines: medicines,
        reminders: const [],
        intakeRecords: const [],
      );

  test('empty query is idle', () {
    expect(searchKits(state(const []), '  ', now), isA<KitSearchIdle>());
  });

  test('groups by kit, selected kit first, by name and ingredient', () {
    final result = searchKits(
      state([
        package('mom1', 'Ибупрофен', kit: 'mom', expiry: DateTime(2027, 11)),
        package('h1', 'Ибупрофен', expiry: DateTime(2028, 9)),
        package('h2', 'ИБУПРОФЕН', expiry: DateTime(2026, 9, 22)),
        package(
          'h3',
          'Нурофен',
          ingredient: 'Ибупрофен',
          quantity: 0,
          expiry: DateTime(2027),
        ),
        package('h4', 'Парацетамол'),
      ]),
      'ибупрофен',
      now,
    );
    expect(result, isA<KitSearchByName>());
    final byName = result as KitSearchByName;
    expect(byName.missing, isNull);
    expect(byName.groups.map((group) => group.title), [
      'Дом · 3 упаковки',
      'Аптечка мамы · общая',
    ]);
    final home = byName.groups.first.hits;
    expect(home.map((hit) => hit.package.id), ['h2', 'h1', 'h3']);
    expect(home.last.ingredient, 'ибупрофен');
    expect(home.first.ingredient, isNull);
  });

  test('ё and е match each other', () {
    final result = searchKits(
      state([package('a', 'Зелёнка')]),
      'зеленка',
      now,
    );
    expect(result, isA<KitSearchByName>());
    expect(normalizeSearchText('  Ёлка   зелёная '), 'елка зеленая');
  });

  test('found only in another kit: banner with the kit and place', () {
    final result =
        searchKits(
              state([
                package(
                  'd1',
                  'Траумель С',
                  kit: 'dacha',
                  place: 'Ящик в прихожей',
                ),
              ]),
              'траумель',
              now,
            )
            as KitSearchByName;
    expect(result.groups.single.title, 'Дача');
    expect(result.missing!.title, 'В «Доме» нет');
    expect(result.missing!.text, 'Нашли в аптечке «Дача» — ящик в прихожей');
  });

  test('found in several other kits', () {
    final result =
        searchKits(
              state([
                package('d1', 'Траумель С', kit: 'dacha'),
                package('c1', 'Траумель С', kit: 'car'),
              ]),
              'траумель',
              now,
            )
            as KitSearchByName;
    expect(result.missing!.text, 'Нашли в аптечках «Дача» и «Машина»');
  });

  test('nothing found names how many kits were searched', () {
    final result = searchKits(state(const []), 'аспирин', now);
    expect(
      (result as KitSearchNothing).text,
      'Искали «аспирин» в 4 аптечках по названию и действующему веществу.',
    );
  });

  test('symptom: usable, undated and expired groups; used up left out', () {
    final result = searchKits(
      state([
        package(
          'p1',
          'Парацетамол',
          expiry: DateTime(2027, 3),
          purpose: MedicinePurpose.fever,
        ),
        package(
          'p2',
          'Ибупрофен',
          expiry: DateTime(2026, 9, 22),
          purpose: MedicinePurpose.fever,
        ),
        package(
          'p3',
          'Цефекон Д',
          kit: 'dacha',
          expiry: DateTime(2026, 8),
          purpose: MedicinePurpose.fever,
        ),
        package('p4', 'Нурофен', purpose: MedicinePurpose.fever),
        package(
          'p5',
          'Панадол',
          quantity: 0,
          expiry: DateTime(2027),
          purpose: MedicinePurpose.fever,
        ),
        package('p6', 'Називин', purpose: MedicinePurpose.runnyNose),
      ]),
      'температура',
      now,
    );
    expect(result, isA<KitSearchBySymptom>());
    final groups = (result as KitSearchBySymptom).groups;
    expect(groups.map((group) => group.title), [
      'Можно использовать по сроку',
      'Срок не указан',
      'Не используйте',
    ]);
    expect(groups[0].hits.map((hit) => hit.package.id), ['p2', 'p1']);
    expect(groups[1].hits.single.package.id, 'p4');
    expect(groups[2].hits.single.package.id, 'p3');
  });

  test('symptom without marked packages', () {
    final result = searchKits(state(const []), 'Горло', now);
    expect(
      (result as KitSearchNothing).text,
      'Искали «Боль в горле» в 4 аптечках по отметкам «Для чего».',
    );
  });

  test('symptomQuery matches the whole label only', () {
    expect(symptomQuery('Головная боль'), MedicinePurpose.headache);
    expect(symptomQuery(' кашель '), MedicinePurpose.cough);
    expect(symptomQuery('кашель сироп'), isNull);
    expect(symptomQuery(''), isNull);
  });

  test('kitLocative declines simple names and keeps the rest', () {
    expect(kitLocative('Дом'), 'В «Доме»');
    expect(kitLocative('Дача'), 'В «Даче»');
    expect(kitLocative('Машина'), 'В «Машине»');
    expect(kitLocative('Кухня'), 'В «Кухне»');
    expect(kitLocative('Аптечка мамы'), 'В аптечке «Аптечка мамы»');
    expect(kitLocative('Офис 2'), 'В аптечке «Офис 2»');
    expect(kitLocative('Портфель'), 'В аптечке «Портфель»');
  });
}
