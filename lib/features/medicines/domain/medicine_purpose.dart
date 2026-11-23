/// «Для чего» marks. Picker order follows «Выбор / Для чего» (894:17683);
/// «Боль в ухе» and «Раны» are not in that sheet but «Состояние аптечки»
/// (863:12157) has categories for them, so they stay selectable.
/// The enum name is persisted.
enum MedicinePurpose {
  fever('Температура', chipIcon: 'symptom/fever'),
  headache('Головная боль', chipIcon: 'symptom/headache'),
  runnyNose('Насморк', chipIcon: 'symptom/runny_nose'),
  cough('Кашель', chipIcon: 'symptom/cough'),
  throat('Боль в горле', chipIcon: 'symptom/throat'),
  stomach('Живот', chipIcon: 'symptom/stomach'),
  allergy('Аллергия', ownIcon: 'purpose/allergy'),
  ear('Боль в ухе', ownIcon: 'purpose/ear'),
  wounds('Раны', ownIcon: 'purpose/wounds'),
  pressure('Давление'),
  vitamins('Витамины'),
  other('Другое');

  const MedicinePurpose(this.label, {this.chipIcon, this.ownIcon});
  final String label;

  /// 16 pt icon of the picker chip (in `assets/icons/figma/`); the sheet
  /// shows the other marks without an icon.
  final String? chipIcon;

  /// An «icons / Purpose» icon for marks without a chip icon.
  final String? ownIcon;

  /// Icon of the «для чего» tag on the package card and of the «Для чего»
  /// fact: the chip icon, a «icons / Purpose» one or «?».
  String get tagIcon => chipIcon ?? ownIcon ?? 'purpose-unknown-24';

  static MedicinePurpose? parse(String? value) =>
      MedicinePurpose.values.where((item) => item.name == value).firstOrNull;
}

/// Icon of a «Свой вариант» mark.
const customPurposeIcon = 'purpose-unknown-24';

/// «Температура, Головная боль, Ушибы»; `null` when nothing is marked.
String? purposesLabel(List<MedicinePurpose> purposes, String? custom) {
  final labels = [
    for (final purpose in purposes) purpose.label,
    if (custom != null && custom.trim().isNotEmpty) custom.trim(),
  ];
  return labels.isEmpty ? null : labels.join(', ');
}
