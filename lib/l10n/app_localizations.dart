import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ta.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ta')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Transcription System'**
  String get appTitle;

  /// No description provided for @apiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Enter Groq API Key'**
  String get apiKeyLabel;

  /// No description provided for @apiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Paste your API key here'**
  String get apiKeyHint;

  /// No description provided for @retryTitle.
  ///
  /// In en, this message translates to:
  /// **'Transcription Incomplete'**
  String get retryTitle;

  /// No description provided for @retryMessage.
  ///
  /// In en, this message translates to:
  /// **'Audio was safely saved to your device, but transcription could not be completed. Would you like to retry?'**
  String get retryMessage;

  /// No description provided for @retryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry Transcription'**
  String get retryButton;

  /// No description provided for @discardButton.
  ///
  /// In en, this message translates to:
  /// **'Discard Recording'**
  String get discardButton;

  /// No description provided for @maxDurationReached.
  ///
  /// In en, this message translates to:
  /// **'Maximum recording duration reached. Finalizing recording...'**
  String get maxDurationReached;

  /// No description provided for @livePreviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Live speech preview is currently unavailable.'**
  String get livePreviewUnavailable;

  /// No description provided for @errorNoApiKey.
  ///
  /// In en, this message translates to:
  /// **'No Groq API key configured. Please set your API key in Settings or environment.'**
  String get errorNoApiKey;

  /// No description provided for @errorInvalidApiKey.
  ///
  /// In en, this message translates to:
  /// **'Invalid API key. Please check your Groq API key in Settings.'**
  String get errorInvalidApiKey;

  /// No description provided for @errorFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The audio file is too large for transcription (maximum 25 MB).'**
  String get errorFileTooLarge;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'API rate limit reached. Please wait a moment and try again.'**
  String get errorRateLimited;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'The operation timed out. Please try with a shorter audio segment.'**
  String get errorTimeout;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network communication failure. Please check your internet connection.'**
  String get errorNetwork;

  /// No description provided for @errorServer.
  ///
  /// In en, this message translates to:
  /// **'Transcription server error occurred. Please try again later.'**
  String get errorServer;

  /// No description provided for @errorEmptyResult.
  ///
  /// In en, this message translates to:
  /// **'No speech could be recognized from the audio.'**
  String get errorEmptyResult;

  /// No description provided for @errorFileMissing.
  ///
  /// In en, this message translates to:
  /// **'The selected audio file was not found on the device.'**
  String get errorFileMissing;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred.'**
  String get errorUnknown;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ta'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ta':
      return AppLocalizationsTa();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
