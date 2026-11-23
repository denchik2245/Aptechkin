import 'package:aptechka/app/app.dart';
import 'package:aptechka/features/onboarding/data/onboarding_store.dart';
import 'package:aptechka/features/settings/data/backup_files.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OnboardingStore.load();
  await BackupStore.load();
  runApp(const ProviderScope(child: AptechkaApp()));
}
