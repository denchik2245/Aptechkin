/// Every route path in one place. Screens navigate with these constants and
/// helpers instead of string literals, so a path changes in one file.
abstract final class AppRoutes {
  static const onboarding = '/onboarding';
  static const notificationsPrompt = '/onboarding/notifications';

  static const kits = '/';
  static const inventory = '/inventory';
  static const reminders = '/reminders';
  static const settings = '/settings';

  /// «Настройки» (1194:16667 …): nested in the settings tab, so the tab bar
  /// stays. [settingsBackupSaved] and [settingsRestore] need `extra`.
  static const settingsAppearance = '/settings/appearance';
  static const settingsNotifications = '/settings/notifications';
  static const settingsDigest = '/settings/notifications/digest';
  static const settingsThresholds = '/settings/thresholds';
  static const settingsBackup = '/settings/backup';
  static const settingsBackupSaved = '/settings/backup/saved';
  static const settingsRestore = '/settings/backup/restore';
  static const settingsHelp = '/settings/help';
  static const settingsAbout = '/settings/about';

  static const search = '/search';
  static const account = '/account';
  static const accountPrivacy = '/account/privacy';
  static const scanner = '/scanner';

  /// Scanner that returns the GTIN to the caller instead of adding.
  static const scannerPick = '/scanner?pick=1';

  /// «Несколько упаковок подряд» (890:15548): scanned packages are added
  /// from a quick card, then [addSummary] lists them.
  static const scannerBatch = '/scanner?batch=1';
  static const addSummary = '/scanner/summary';
  static const places = '/places';

  /// «Состояние аптечки» (863:12157) and one of its categories.
  static String kitState(String kitId) => '/kits/$kitId/state';
  static String kitStateCategory(String kitId, String category) =>
      '/kits/$kitId/state/$category';

  static const medicineSelect = '/medicine/select';

  /// «Поиск по названию» already filled with [query].
  static String medicineSelectQuery(String query) =>
      Uri(path: medicineSelect, queryParameters: {'q': query}).toString();
  static const medicineVariants = '/medicine/variants';
  static const medicineNew = '/medicine/new';
  static String medicine(String id) => '/medicine/$id';

  /// «Изменить упаковку» (894:18072): the package form in edit mode.
  static String medicineEdit(String id) => '/medicine/$id/edit';

  static const treatmentNew = '/treatment/new';
  static String treatmentEdit(String id) => '$treatmentNew?edit=$id';
  static String treatmentRepeat(String id) => '$treatmentNew?repeat=$id';
  static String course(String id) => '/treatment/course/$id';
  static String courseHistory(String id) => '/treatment/course/$id/history';
  static String notificationPreview(String id) => '/treatment/notification/$id';
}
