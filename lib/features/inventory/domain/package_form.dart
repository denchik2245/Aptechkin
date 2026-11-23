import 'package:aptechka/core/utils/russian_count.dart';

/// How «stock control» (874:12559) counts a package: pieces, an
/// approximate level, or not at all (devices).
enum StockMode { count, level, off }

/// Expiry choice of the form section «Срок годности».
enum ExpiryChoice { date, later, none }

/// A row of «Форма выпуска» (section 5 · 890:15550). [form] is stored on
/// the package, [unit] is used for counting, [icon] is in `assets/icons/figma/`.
class DrugFormOption {
  const DrugFormOption(this.label, this.form, this.unit, this.icon);
  final String label;
  final String form;
  final String unit;
  final String icon;
}

const drugFormOptions = <DrugFormOption>[
  DrugFormOption('Таблетки, капсулы', 'Таблетки', 'таблеток', 'form/pills'),
  DrugFormOption('Капли', 'Капли', 'флакон', 'form/drops'),
  DrugFormOption('Сироп, суспензия, раствор', 'Сироп', 'флакон', 'form/drops'),
  DrugFormOption('Мазь, крем, гель', 'Мазь', 'тюбик', 'form/cream'),
  DrugFormOption('Спрей', 'Спрей', 'флакон', 'form/spray'),
  DrugFormOption('Порошок, пакетики', 'Порошок', 'пакетиков', 'form/powder'),
  DrugFormOption('Свечи', 'Свечи', 'свечей', 'form/pills'),
  DrugFormOption('Ампулы, шприцы', 'Ампулы', 'ампул', 'form/syringe'),
  DrugFormOption('Пластырь, бинт', 'Пластырь', 'шт.', 'form/bandage'),
  DrugFormOption('Прибор', 'Прибор', 'шт.', 'form/other'),
];

bool _has(String text, List<String> stems) => stems.any(text.contains);

const _deviceStems = [
  'прибор',
  'термометр',
  'тонометр',
  'глюкометр',
  'изделие',
];
const _pieceStems = [
  'таблет',
  'капсул',
  'драже',
  'пастил',
  'свеч',
  'суппоз',
  'ампул',
  'шприц',
  'пакет',
  'саше',
  'пластыр',
  'бинт',
];
const _creamStems = ['мазь', 'крем', 'гель', 'бальзам', 'линимент'];
const _levelStems = [
  'капл',
  'сироп',
  'суспенз',
  'раствор',
  'эмульс',
  'настойк',
  'спрей',
  'аэрозол',
  ..._creamStems,
];

/// Counting mode by the description of «stock control»: pieces for tablets,
/// capsules, suppositories, ampoules, sachets and plasters; a level for
/// drops, syrups, solutions, sprays and creams; none for devices.
StockMode stockModeFor(String form, {String unit = ''}) {
  final text = form.toLowerCase();
  if (_has(text, _deviceStems)) return StockMode.off;
  if (_has(text, _pieceStems)) return StockMode.count;
  if (_has(text, _levelStems)) return StockMode.level;
  final lowerUnit = unit.toLowerCase();
  if (_has(lowerUnit, ['мл', 'флакон', 'тюбик'])) return StockMode.level;
  return StockMode.count;
}

/// Unit for counting pieces of [form] when the catalog does not give one.
String countUnitFor(String form) {
  final text = form.toLowerCase();
  if (text.contains('таблет')) return 'таблеток';
  if (text.contains('капсул')) return 'капсул';
  if (text.contains('драже')) return 'драже';
  if (_has(text, ['свеч', 'суппоз'])) return 'свечей';
  if (text.contains('ампул')) return 'ампул';
  if (_has(text, ['пакет', 'саше', 'порош'])) return 'пакетиков';
  if (text.contains('пластыр')) return 'пластырей';
  return 'шт.';
}

/// Container of a level-counted package: «тюбик» for creams, else «флакон».
String containerFor(String form) =>
    _has(form.toLowerCase(), _creamStems) ? 'тюбик' : 'флакон';

/// Switch label of the section «Вскрытие».
String openedSwitchLabel(String form) => switch (stockModeFor(form)) {
  StockMode.level =>
    containerFor(form) == 'тюбик' ? 'Тюбик уже вскрыт' : 'Флакон уже вскрыт',
  _ => 'Упаковка уже вскрыта',
};

/// Choices of «Срок после вскрытия», in days.
const afterOpeningOptions = <int>[7, 14, 28, 30, 60, 90, 180];

/// «28 дней», «6 месяцев», «1 год».
String afterOpeningLabel(int days) {
  if (days == 365) return '1 год';
  if (days >= 60 && days % 30 == 0) {
    final months = days ~/ 30;
    return russianCount(months, 'месяц', 'месяца', 'месяцев');
  }
  return russianCount(days, 'день', 'дня', 'дней');
}

const _monthNames = [
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
  'Август',
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
];

/// «Сентябрь 2028».
String monthYearLabel(DateTime date) =>
    '${_monthNames[date.month - 1]} ${date.year}';

String monthName(int month) => _monthNames[month - 1];

/// The package is usable until the end of the printed month.
DateTime endOfMonth(int year, int month) => DateTime(year, month + 1, 0);

/// Errors of «Форма / Ошибки заполнения» (890:16738).
class PackageFormErrors {
  const PackageFormErrors({this.name, this.form, this.expiry});
  final String? name;
  final String? form;
  final String? expiry;

  bool get isEmpty => name == null && form == null && expiry == null;
}

PackageFormErrors validatePackageForm({
  required String name,
  required String form,
  required ExpiryChoice expiryChoice,
  required DateTime? expiry,
}) => PackageFormErrors(
  name: name.trim().isEmpty ? 'Введите название с упаковки' : null,
  form: form.trim().isEmpty
      ? 'Выберите форму — от неё зависит, как считать остаток'
      : null,
  expiry: expiryChoice == ExpiryChoice.date && expiry == null
      ? 'Укажите срок или выберите «Укажу позже»'
      : null,
);
