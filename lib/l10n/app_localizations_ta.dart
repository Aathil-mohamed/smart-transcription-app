// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tamil (`ta`).
class AppLocalizationsTa extends AppLocalizations {
  AppLocalizationsTa([String locale = 'ta']) : super(locale);

  @override
  String get appTitle => 'ஸ்கிரிப்லி';

  @override
  String get apiKeyLabel => 'Groq API விசையை உள்ளிடவும்';

  @override
  String get apiKeyHint => 'உங்கள் API விசையை இங்கே ஒட்டவும்';

  @override
  String get retryTitle => 'டிரான்ஸ்கிரிப்ஷன் முழுமையடையவில்லை';

  @override
  String get retryMessage =>
      'ஆடியோ சாதனத்தில் பாதுகாப்பாக சேமிக்கப்பட்டுள்ளது, ஆனால் டிரான்ஸ்கிரிப்ஷனை முடிக்க முடியவில்லை. மீண்டும் முயற்சிக்க விரும்புகிறீர்களா?';

  @override
  String get retryButton => 'மீண்டும் முயற்சி செய்';

  @override
  String get discardButton => 'ஆடியோவை நிராகரி';

  @override
  String get maxDurationReached =>
      'அதிகபட்ச பதிவு நேரம் முடிந்தது. ஆடியோ சேமிக்கப்படுகிறது...';

  @override
  String get livePreviewUnavailable =>
      'நேரடி பேச்சு முன்னோட்டம் தற்போது கிடைக்கவில்லை.';

  @override
  String get errorNoApiKey =>
      'Groq API விசை உள்ளமைக்கப்படவில்லை. அமைப்புகளில் உங்கள் API விசையை அமைக்கவும்.';

  @override
  String get errorInvalidApiKey =>
      'தவறான API விசை. அமைப்புகளில் உங்கள் Groq API விசையைச் சரிபார்க்கவும்.';

  @override
  String get errorFileTooLarge =>
      'ஆடியோ கோப்பு டிரான்ஸ்கிரிப்ஷனுக்கு மிகவும் பெரியது (அதிகபட்சம் 25 MB).';

  @override
  String get errorRateLimited =>
      'API வரம்பு அடைந்தது. சிறிது நேரம் கழித்து மீண்டும் முயற்சிக்கவும்.';

  @override
  String get errorTimeout =>
      'செயல்பாட்டின் நேரம் முடிந்தது. குறுகிய ஆடியோவுடன் மீண்டும் முயற்சிக்கவும்.';

  @override
  String get errorNetwork => 'நெட்வொர்க் பிழை. இணைய இணைப்பைச் சரிபார்க்கவும்.';

  @override
  String get errorServer =>
      'சர்வர் பிழை ஏற்பட்டது. பின்னர் மீண்டும் முயற்சிக்கவும்.';

  @override
  String get errorEmptyResult =>
      'ஆடியோவிலிருந்து எந்த பேச்சையும் அடையாளம் காண முடியவில்லை.';

  @override
  String get errorFileMissing =>
      'தேர்ந்தெடுக்கப்பட்ட ஆடியோ கோப்பு சாதனத்தில் கிடைக்கவில்லை.';

  @override
  String get errorUnknown => 'எதிர்பாராத பிழை ஏற்பட்டது.';

  @override
  String transcriptionDetails(
      String provider, String detectedLang, int segments, int dropped) {
    return 'இயந்திரம்: $provider • கண்டறியப்பட்டது: $detectedLang • பகுதிகள்: $segments (நீக்கப்பட்டது: $dropped)';
  }
}
