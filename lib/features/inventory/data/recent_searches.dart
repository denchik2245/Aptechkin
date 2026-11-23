import 'package:shared_preferences/shared_preferences.dart';

/// «Недавние» chips, newest first. Kept on the device, not in a profile.
class RecentSearches {
  const RecentSearches._(this._key);

  /// «Поиск по названию» (893:17164): names opened from the catalog.
  static const drugs = RecentSearches._('aptechka_recent_drug_searches_v1');

  /// «Поиск по всем аптечкам» (835:8835): queries whose result was opened.
  static const kits = RecentSearches._('aptechka_recent_kit_searches_v1');

  static const limit = 5;

  final String _key;

  Future<List<String>> load() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(_key) ?? const [];
  }

  /// Puts [name] first; the same name (any case) is kept once.
  Future<List<String>> remember(String name) async {
    final value = name.trim();
    final preferences = await SharedPreferences.getInstance();
    final current = preferences.getStringList(_key) ?? const [];
    if (value.isEmpty) return current;
    final next = rememberRecent(current, value);
    await preferences.setStringList(_key, next);
    return next;
  }
}

/// Pure part of [RecentSearches.remember].
List<String> rememberRecent(List<String> current, String name) => [
  name,
  for (final item in current)
    if (item.toLowerCase() != name.toLowerCase()) item,
].take(RecentSearches.limit).toList();
