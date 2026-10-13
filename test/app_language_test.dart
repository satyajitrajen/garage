import 'package:flutter_test/flutter_test.dart';
import 'package:garage_manager/l10n/app_language.dart';
import 'package:garage_manager/l10n/strings_mr.dart';
import 'package:garage_manager/models/job_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => AppLanguage.instance.set('en'));

  test('English is the default and passes text through', () {
    expect(AppLanguage.code, 'en');
    expect(tr('Jobs'), 'Jobs');
  });

  test('Marathi translates known strings and falls back for unknown ones', () async {
    await AppLanguage.instance.set('mr');
    expect(tr('Jobs'), marathiStrings['Jobs']);
    expect(JobStatus.inProgress.shortName, marathiStrings['In Progress']);
    expect(tr('Some untranslated text'), 'Some untranslated text');
  });

  test('choice is saved and restored', () async {
    await AppLanguage.instance.set('mr');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_language'), 'mr');
    await AppLanguage.load();
    expect(AppLanguage.code, 'mr');
  });

  test('every translation is non-empty', () {
    for (final entry in marathiStrings.entries) {
      expect(entry.value.trim(), isNotEmpty, reason: entry.key);
    }
  });
}
