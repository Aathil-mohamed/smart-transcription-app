// Generated firebase configuration derived from android/app/google-services.json
// and adapted for iOS. For exact web configuration run `flutterfire configure`.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Web settings: these are best-effort values. Use `flutterfire configure`
  // to generate exact web app credentials if you have a dedicated web app.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBnXGWZT2CtfBgr508JdWENpgvFSulPPNU',
    authDomain: 'smart-transcription-app.firebaseapp.com',
    projectId: 'smart-transcription-app',
    storageBucket: 'smart-transcription-app.firebasestorage.app',
    messagingSenderId: '863918765256',
    appId: '1:863918765256:web:0000000000000000',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBnXGWZT2CtfBgr508JdWENpgvFSulPPNU',
    appId: '1:863918765256:android:50bcca6b8389d909dd61fd',
    messagingSenderId: '863918765256',
    projectId: 'smart-transcription-app',
    storageBucket: 'smart-transcription-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBnXGWZT2CtfBgr508JdWENpgvFSulPPNU',
    appId: '1:863918765256:ios:0000000000000000000000',
    messagingSenderId: '863918765256',
    projectId: 'smart-transcription-app',
    storageBucket: 'smart-transcription-app.firebasestorage.app',
    iosBundleId: 'com.smarttranscribe.smart_transcription_app',
  );
}
