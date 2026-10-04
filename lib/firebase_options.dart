// Gerado como placeholder para o MVP.
// Substitua este arquivo executando: flutterfire configure
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return const FirebaseOptions(apiKey: 'REPLACE_ME', appId: 'REPLACE_ME', messagingSenderId: 'REPLACE_ME', projectId: 'REPLACE_ME', storageBucket: 'REPLACE_ME');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const FirebaseOptions(apiKey: 'REPLACE_ME', appId: 'REPLACE_ME', messagingSenderId: 'REPLACE_ME', projectId: 'REPLACE_ME', storageBucket: 'REPLACE_ME');
      default:
        throw UnsupportedError('Plataforma não configurada. Execute flutterfire configure.');
    }
  }
}
