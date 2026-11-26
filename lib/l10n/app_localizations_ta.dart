// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tamil (`ta`).
class AppLocalizationsTa extends AppLocalizations {
  AppLocalizationsTa([String locale = 'ta']) : super(locale);

  @override
  String get appTitle => 'ஸ்மார்ட் டிரான்ஸ்கிரிப்ஷன் சிஸ்டம்';

  @override
  String get errorNoApiKey =>
      'Groq API விசை உள்ளமைக்கப்படவில்லை. அமைப்புகள் அல்லது சூழலில் உங்கள் API விசையை அமைக்கவும்.';

  @override
  String get errorInvalidApiKey =>
      'தவறான API விசை. அமைப்புகளில் உங்கள் Groq API விசையைச் சரிபார்க்கவும்.';

  @override
  String get errorFileTooLarge =>
      'ஆடியோ கோப்பு மிக பெரியதாக உள்ளது (அதிகபட்சம் 25 MB).';

  @override
  String get errorRateLimited =>
      'API விகித வரம்பு எட்டப்பட்டது. சிறிது நேரம் கழித்து மீண்டும் முயற்சிக்கவும்.';

  @override
  String get errorTimeout =>
      'செயல்பாட்டு நேரம் முடிந்தது. குறுகிய ஆடியோ மூலம் மீண்டும் முயற்சிக்கவும்.';

  @override
  String get errorNetwork =>
      'நெட்வொர்க் இணைப்பு தோல்வியடைந்தது. உங்கள் இணைய இணைப்பைச் சரிபார்க்கவும்.';

  @override
  String get errorServer =>
      'டிரான்ஸ்கிரிப்ஷன் சர்வர் பிழை ஏற்பட்டது. பின்னர் முயற்சிக்கவும்.';

  @override
  String get errorEmptyResult =>
      'ஆடியோவிலிருந்து எந்த பேச்சையும் அடையாளம் காண முடியவில்லை.';

  @override
  String get errorFileMissing =>
      'தேர்ந்தெடுக்கப்பட்ட ஆடியோ கோப்பு சாதனத்தில் கிடைக்கவில்லை.';

  @override
  String get errorUnknown => 'எதிர்பாராத பிழை ஏற்பட்டது.';
}
