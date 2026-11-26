// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Smart Transcription System';

  @override
  String get apiKeyLabel => 'Enter Groq API Key';

  @override
  String get apiKeyHint => 'Paste your API key here';

  @override
  String get retryTitle => 'Transcription Incomplete';

  @override
  String get retryMessage =>
      'Audio was safely saved to your device, but transcription could not be completed. Would you like to retry?';

  @override
  String get retryButton => 'Retry Transcription';

  @override
  String get discardButton => 'Discard Recording';

  @override
  String get maxDurationReached =>
      'Maximum recording duration reached. Finalizing recording...';

  @override
  String get livePreviewUnavailable =>
      'Live speech preview is currently unavailable.';

  @override
  String get errorNoApiKey =>
      'No Groq API key configured. Please set your API key in Settings or environment.';

  @override
  String get errorInvalidApiKey =>
      'Invalid API key. Please check your Groq API key in Settings.';

  @override
  String get errorFileTooLarge =>
      'The audio file is too large for transcription (maximum 25 MB).';

  @override
  String get errorRateLimited =>
      'API rate limit reached. Please wait a moment and try again.';

  @override
  String get errorTimeout =>
      'The operation timed out. Please try with a shorter audio segment.';

  @override
  String get errorNetwork =>
      'Network communication failure. Please check your internet connection.';

  @override
  String get errorServer =>
      'Transcription server error occurred. Please try again later.';

  @override
  String get errorEmptyResult =>
      'No speech could be recognized from the audio.';

  @override
  String get errorFileMissing =>
      'The selected audio file was not found on the device.';

  @override
  String get errorUnknown => 'An unexpected error occurred.';
}
