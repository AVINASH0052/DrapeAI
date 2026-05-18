import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios; // reuse iOS config for macOS
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBS0XD-UqOoo5pyQPhrHkizJN_yNh-KBz4',
    appId: '1:923334398143:ios:0301a621c48e8f88f5f60a',
    messagingSenderId: '923334398143',
    projectId: 'drapeai-b5af6',
    storageBucket: 'drapeai-b5af6.firebasestorage.app',
    iosClientId: '923334398143-opi7obokm2k0m8flotic5ces8s900s88.apps.googleusercontent.com',
    iosBundleId: 'com.drapeai.drapeai',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBS0XD-UqOoo5pyQPhrHkizJN_yNh-KBz4',
    appId: '1:923334398143:ios:0301a621c48e8f88f5f60a',
    messagingSenderId: '923334398143',
    projectId: 'drapeai-b5af6',
    storageBucket: 'drapeai-b5af6.firebasestorage.app',
  );
}
