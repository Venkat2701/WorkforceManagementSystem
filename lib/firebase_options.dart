import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCtgq5J7oG-D5yE0-x4OBD7gzn0ViQz1WM',
    appId: '1:750710002270:web:3b7feb4e9604de85151acf',
    messagingSenderId: '750710002270',
    projectId: 'foundry-ems',
    authDomain: 'foundry-ems.firebaseapp.com',
    storageBucket: 'foundry-ems.firebasestorage.app',
    measurementId: 'G-NCJ8FG3C9B',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBbaheCefwqR2LftyvlRCE_r6rS87qz91Y',
    appId: '1:750710002270:android:7a4298059dafa4d2151acf',
    messagingSenderId: '750710002270',
    projectId: 'foundry-ems',
    storageBucket: 'foundry-ems.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAvqVsY1JCEVAx12TDeaT5V2GPNBUPZufA',
    appId: '1:750710002270:ios:429d8382e19a8c88151acf',
    messagingSenderId: '750710002270',
    projectId: 'foundry-ems',
    storageBucket: 'foundry-ems.firebasestorage.app',
    iosBundleId: 'com.foundry.ems.foundryEms',
  );

}