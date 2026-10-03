import 'package:firebase_core/firebase_core.dart';

/// Konfigurasi Firebase untuk platform Web.
/// (Android/iOS membaca dari google-services.json / GoogleService-Info.plist.)
class FirebaseConfig {
  FirebaseConfig._();

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyAUs_7vHagR7rc24kkGtxoKpTLbSd9-X4w",
    authDomain: "laundry-ku-id.firebaseapp.com",
    projectId: "laundry-ku-id",
    storageBucket: "laundry-ku-id.firebasestorage.app",
    messagingSenderId: "518877666392",
    appId: "1:518877666392:web:d4885be99c724e5783fe2d",
    measurementId: "G-0W7K571RTN",
  );
}
