/// Icons for a first-aid kit, from the Figma «icons / Kit picker» set
/// (843:10235). The enum name is persisted, so do not rename values.
enum KitIcon {
  home('Дом'),
  apartment('Квартира'),
  dacha('Дача'),
  tent('Палатка'),
  bedroom('Спальня'),
  fridge('Холодильник'),
  car('Машина'),
  plane('Самолёт'),
  suitcase('Чемодан'),
  backpack('Рюкзак'),
  bag('Сумка'),
  work('Работа'),
  person('Человек'),
  family('Семья'),
  child('Ребёнок'),
  heart('Сердце'),
  pet('Питомец'),
  study('Учёба'),
  sport('Спорт'),
  firstaid('Аптечка'),
  pill('Таблетка'),
  shield('Защита'),
  star('Звезда'),
  gift('Подарок');

  const KitIcon(this.label);
  final String label;

  static KitIcon parse(String? value) =>
      KitIcon.values.where((item) => item.name == value).firstOrNull ??
      KitIcon.home;

  /// Suggests an icon from a kit name, e.g. «Машина» → [car].
  static KitIcon suggest(String name) {
    final text = name.trim().toLowerCase();
    for (final (pattern, icon) in const [
      ('дач', KitIcon.dacha),
      ('машин', KitIcon.car),
      ('авто', KitIcon.car),
      ('поход', KitIcon.tent),
      ('путеш', KitIcon.suitcase),
      ('отпуск', KitIcon.suitcase),
      ('работ', KitIcon.work),
      ('офис', KitIcon.work),
      ('ребён', KitIcon.child),
      ('ребен', KitIcon.child),
      ('дет', KitIcon.child),
      ('мам', KitIcon.heart),
      ('бабуш', KitIcon.heart),
      ('кот', KitIcon.pet),
      ('собак', KitIcon.pet),
      ('спорт', KitIcon.sport),
      ('квартир', KitIcon.apartment),
    ]) {
      if (text.contains(pattern)) return icon;
    }
    return KitIcon.home;
  }
}

/// Groups as shown in the «Иконка аптечки» sheet.
const kitIconGroups = <(String, List<KitIcon>)>[
  (
    'Места',
    [
      KitIcon.home,
      KitIcon.apartment,
      KitIcon.dacha,
      KitIcon.tent,
      KitIcon.bedroom,
      KitIcon.fridge,
    ],
  ),
  (
    'Поездки',
    [
      KitIcon.car,
      KitIcon.plane,
      KitIcon.suitcase,
      KitIcon.backpack,
      KitIcon.bag,
      KitIcon.work,
    ],
  ),
  (
    'Для кого',
    [
      KitIcon.person,
      KitIcon.family,
      KitIcon.child,
      KitIcon.heart,
      KitIcon.pet,
      KitIcon.study,
    ],
  ),
  (
    'Другое',
    [
      KitIcon.sport,
      KitIcon.firstaid,
      KitIcon.pill,
      KitIcon.shield,
      KitIcon.star,
      KitIcon.gift,
    ],
  ),
];
