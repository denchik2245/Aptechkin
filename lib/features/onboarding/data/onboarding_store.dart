import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-level onboarding flags. They are not part of a profile's
/// [AppState], so switching profiles never shows onboarding again.
class OnboardingStore {
  OnboardingStore._();

  static const _completedKey = 'aptechka_onboarding_completed_v1';
  static const _notificationPromptKey = 'aptechka_notification_prompt_v1';
  static const _cameraIntroKey = 'aptechka_camera_intro_v1';

  /// `null` until [load] runs; the router does not redirect while unknown.
  /// Widget tests never call [load], so they start on the requested route.
  static final completed = ValueNotifier<bool?>(null);
  static bool _notificationPromptShown = true;
  static bool _cameraIntroShown = true;

  static Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    // Existing installs already have data and skip onboarding.
    final hasData = preferences.getKeys().any(
      (key) => key.startsWith('aptechka_state') ||
          key.startsWith('aptechka_profile_'),
    );
    completed.value = preferences.getBool(_completedKey) ?? hasData;
    _notificationPromptShown =
        preferences.getBool(_notificationPromptKey) ?? hasData;
    _cameraIntroShown = preferences.getBool(_cameraIntroKey) ?? false;
  }

  static Future<void> complete() async {
    completed.value = true;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_completedKey, true);
  }

  /// The notifications prompt is shown once, after the first saved medicine.
  static bool get shouldPromptNotifications => !_notificationPromptShown;

  /// «Перед доступом к камере» is shown once, before the system request.
  static bool get shouldExplainCamera => !_cameraIntroShown;

  static Future<void> markCameraIntroShown() async {
    _cameraIntroShown = true;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_cameraIntroKey, true);
  }

  static Future<void> markNotificationPromptShown() async {
    _notificationPromptShown = true;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_notificationPromptKey, true);
  }
}
