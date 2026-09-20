import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart' as native;
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart'
    as desktop;
import 'google_auth_config.dart';
import '../../core/database/vault_sync_service.dart';

/// Handles "Sign in with Google" on both Android and Windows, then
/// exchanges that sign-in for a Firebase Auth session.
///
/// Firebase Auth is what gives every user a stable, unique ID (UID). That
/// UID is what keeps each person's vault key and entries separate in
/// Firestore, see VaultAccessService and Firestore security rules.
///
/// Two different sign-in paths are used, deliberately:
///
///  - ANDROID uses the official `google_sign_in` package directly, with
///    `serverClientId` set to the Firebase-generated Web Client ID. This
///    is required by google_sign_in 7.x+ to get back a Firebase-valid ID
///    token. The `google_sign_in_all_platforms` wrapper has no way to
///    pass that value through, and passing our Desktop OAuth credentials
///    there instead broke Android sign-in entirely (a Desktop-type OAuth
///    client isn't valid for Android's native flow).
///  - WINDOWS uses `google_sign_in_all_platforms`, which opens the
///    system browser for a loopback OAuth flow using the Desktop OAuth
///    Client ID/Secret from google_auth_config.dart.
class GoogleAuthService {
  static bool _androidInitialized = false;

  static final desktop.GoogleSignIn _desktopSignIn = desktop.GoogleSignIn(
    params: const desktop.GoogleSignInParams(
      clientId: GoogleAuthConfig.desktopClientId,
      clientSecret: GoogleAuthConfig.desktopClientSecret,
      scopes: ['openid', 'profile', 'email'],
      redirectPort: 3000,
    ),
  );

  static User? get currentUser => FirebaseAuth.instance.currentUser;

  static Stream<User?> get authStateChanges =>
      FirebaseAuth.instance.authStateChanges();

  /// Triggers the Google sign-in flow, then signs into Firebase with the
  /// resulting credential. Returns the signed-in Firebase user, or null
  /// if the user cancelled.
  static Future<User?> signIn() async {
    if (Platform.isAndroid) {
      return _signInAndroid();
    }
    return _signInDesktop();
  }

  static Future<User?> _signInAndroid() async {
    final signIn = native.GoogleSignIn.instance;

    if (!_androidInitialized) {
      await signIn.initialize(serverClientId: GoogleAuthConfig.webClientId);
      _androidInitialized = true;
    }

    final native.GoogleSignInAccount account;
    try {
      account = await signIn.authenticate();
    } on native.GoogleSignInException catch (e) {
      if (e.code == native.GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }

    final idToken = account.authentication.idToken;
    final authorization = await account.authorizationClient
        .authorizationForScopes(['email', 'profile']);

    final firebaseCredential = GoogleAuthProvider.credential(
      idToken: idToken,
      accessToken: authorization?.accessToken,
    );

    final userCredential =
        await FirebaseAuth.instance.signInWithCredential(firebaseCredential);
    await VaultSyncService.pullFromCloud();
    return userCredential.user;
  }

  static Future<User?> _signInDesktop() async {
    final credentials = await _desktopSignIn.signIn();
    if (credentials == null) return null;

    final firebaseCredential = GoogleAuthProvider.credential(
      idToken: credentials.idToken,
      accessToken: credentials.accessToken,
    );

    final userCredential =
        await FirebaseAuth.instance.signInWithCredential(firebaseCredential);
    await VaultSyncService.pullFromCloud();
    return userCredential.user;
  }

  static Future<void> signOut() async {
    if (Platform.isAndroid) {
      await native.GoogleSignIn.instance.signOut();
    } else {
      await _desktopSignIn.signOut();
    }
    await FirebaseAuth.instance.signOut();
  }
}
