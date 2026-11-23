import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Saving and opening backup files. Screens use [backupFilesProvider], so
/// tests replace the platform dialogs with a fake.
abstract interface class BackupFiles {
  /// Hands [json] to the system as [fileName]: the share sheet on Android
  /// and iPhone («Сохранить в Файлы», Диск, мессенджер), a download in a
  /// desktop browser. `false` when the person closed the sheet.
  Future<bool> save(String json, String fileName);

  /// Text of a picked `.json` file, `null` when nothing was picked.
  Future<String?> pick();
}

final backupFilesProvider = Provider<BackupFiles>(
  (ref) => const PlatformBackupFiles(),
);

class PlatformBackupFiles implements BackupFiles {
  const PlatformBackupFiles();

  @override
  Future<bool> save(String json, String fileName) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            utf8.encode(json),
            mimeType: 'application/json',
            name: fileName,
          ),
        ],
        fileNameOverrides: [fileName],
        title: 'Резервная копия «Аптечки»',
      ),
    );
    return result.status != ShareResultStatus.dismissed;
  }

  @override
  Future<String?> pick() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Резервная копия',
          extensions: ['json'],
          // Android filters by MIME type; files saved from a messenger or
          // a download often come as octet-stream.
          mimeTypes: ['application/json', 'application/octet-stream'],
          uniformTypeIdentifiers: ['public.json'],
        ),
      ],
    );
    return file?.readAsString();
  }
}

/// When a backup copy was last saved on this device. A device fact like the
/// onboarding flags, so it is not part of [AppState] and not in the backup.
abstract final class BackupStore {
  static const _key = 'aptechka_last_backup_v1';

  /// Stays `null` in widget tests, which never call [load].
  static final lastSavedAt = ValueNotifier<DateTime?>(null);

  static Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    lastSavedAt.value = raw == null ? null : DateTime.tryParse(raw);
  }

  static Future<void> markSaved(DateTime at) async {
    lastSavedAt.value = at;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_key, at.toIso8601String());
    } catch (_) {
      // The date only labels «Резервная копия»; the copy itself is saved.
    }
  }
}
