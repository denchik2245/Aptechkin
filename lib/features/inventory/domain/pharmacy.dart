import 'package:aptechka/features/inventory/domain/kit_icon.dart';

class Pharmacy {
  const Pharmacy({
    required this.id,
    required this.name,
    required this.ownerLabel,
    required this.isShared,
    required this.canEdit,
    this.ownerAccountId,
    this.icon = KitIcon.home,
    this.checkedAt,
    this.places = const [],
  });

  final String id;
  final String name;

  /// Owner's display name; «Вы» for the user's own kits.
  final String ownerLabel;
  final bool isShared;
  final bool canEdit;
  final String? ownerAccountId;
  final KitIcon icon;

  /// When the contents were last checked or changed.
  final DateTime? checkedAt;

  /// Storage places in the user's order («Места хранения»).
  final List<String> places;

  bool get isOwn => ownerLabel == 'Вы';

  /// Second line of the «kit card»: «Общая · владелец Ольга»,
  /// «Только просмотр · владелец Сергей». Own kits have none.
  String? get accessLabel {
    if (isOwn && !isShared) return null;
    final access = canEdit ? 'Общая' : 'Только просмотр';
    return isOwn ? access : '$access · владелец $ownerLabel';
  }

  Pharmacy copyWith({
    String? name,
    KitIcon? icon,
    DateTime? checkedAt,
    String? ownerLabel,
    String? ownerAccountId,
    List<String>? places,
  }) => Pharmacy(
    places: places ?? this.places,
    id: id,
    name: name ?? this.name,
    ownerLabel: ownerLabel ?? this.ownerLabel,
    isShared: isShared,
    canEdit: canEdit,
    ownerAccountId: ownerAccountId ?? this.ownerAccountId,
    icon: icon ?? this.icon,
    checkedAt: checkedAt ?? this.checkedAt,
  );

  Pharmacy withOwner(String accountId) =>
      copyWith(ownerLabel: 'Вы', ownerAccountId: accountId);

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'ownerLabel': ownerLabel,
    'isShared': isShared,
    'canEdit': canEdit,
    'ownerAccountId': ownerAccountId,
    'icon': icon.name,
    'checkedAt': checkedAt?.toIso8601String(),
    'places': places,
  };

  factory Pharmacy.fromJson(Map<String, Object?> json) {
    final name = json['name']! as String;
    final icon = json['icon'] as String?;
    return Pharmacy(
      id: json['id']! as String,
      name: name,
      ownerLabel: json['ownerLabel'] as String? ?? 'Вы',
      isShared: json['isShared'] as bool? ?? false,
      canEdit: json['canEdit'] as bool? ?? true,
      ownerAccountId: json['ownerAccountId'] as String?,
      icon: icon == null ? KitIcon.suggest(name) : KitIcon.parse(icon),
      checkedAt: DateTime.tryParse(json['checkedAt'] as String? ?? ''),
      places: (json['places'] as List?)?.cast<String>() ?? const [],
    );
  }
}
