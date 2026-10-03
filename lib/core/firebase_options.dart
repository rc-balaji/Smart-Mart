import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('This customer app is configured for Android builds.');
    }
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDfX2M1c30Dk-JFjS5Srr78K68sO7vsRpU',
    appId: '1:870512941624:android:8c8306586b0eaa71b664cd',
    messagingSenderId: '870512941624',
    projectId: 'smart-mart-82a7a',
    storageBucket: 'smart-mart-82a7a.firebasestorage.app',
  );
}
