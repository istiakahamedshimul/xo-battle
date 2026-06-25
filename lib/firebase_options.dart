// IMPORTANT: Run `flutterfire configure` to generate this file automatically
// with your Firebase project settings. Replace the placeholder values below
// with the actual values from your Firebase console / flutterfire output.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDw1b3cjOuvIJqtJ30IT19ABR5YKoSB55Y',
    appId: '1:886768883051:android:79911679e6cbae6c02282e',
    messagingSenderId: '886768883051',
    projectId: 'xobattle-6b327',
    storageBucket: 'xobattle-6b327.firebasestorage.app',
  );
}
