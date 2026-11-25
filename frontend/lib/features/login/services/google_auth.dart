import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/constants/google_auth_config.dart';

/// The user closed Google's sign-in without picking an account. Not an
/// error: the login screen just stays as it was.
class GoogleSignInCancelled implements Exception {
  const GoogleSignInCancelled();
}

/// Google's own sign-in UI (Credential Manager on Android, the GoogleSignIn
/// SDK on iOS), through package:google_sign_in 7.x. All it does here is
/// prove who the user is: the ID token goes to the backend, which answers
/// with the app's own session, the same as an email login.
abstract final class GoogleAuth {
  // initialize() must run exactly once, before anything else is called.
  static Future<void>? _initialized;

  static Future<void> _ensureInitialized() {
    return _initialized ??= GoogleSignIn.instance
        .initialize(
          // Android takes its client from the package name + signing
          // certificate; only iOS needs its own client ID passed in.
          clientId: _isApple && GoogleAuthConfig.iosClientId.isNotEmpty ? GoogleAuthConfig.iosClientId : null,
          serverClientId: GoogleAuthConfig.serverClientId,
        )
        .catchError((Object error) {
          // A failed initialize can be tried again on the next tap.
          _initialized = null;
          throw error;
        });
  }

  static bool get _isApple =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS);

  /// Shows Google's account picker and returns the ID token for the chosen
  /// account. Throws [GoogleSignInCancelled] when the user backs out, and an
  /// `Exception` with a message to show for anything else.
  static Future<String> signInForIdToken() async {
    if (!GoogleAuthConfig.isConfigured) {
      debugPrint('Google sign-in: GOOGLE_SERVER_CLIENT_ID was not passed with --dart-define.');
      throw Exception('Google sign-in is not set up in this version of the app.');
    }
    try {
      await _ensureInitialized();
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw Exception('Google sign-in is not available on this device.');
      }
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google did not confirm your account. Please try again.');
      }
      return idToken;
    } on GoogleSignInException catch (error) {
      throw _explain(error);
    }
  }

  /// Ends the Google side of the session, so the next sign-in shows the
  /// account picker again instead of reusing the last account. Never throws:
  /// the app's own session is already gone by the time this runs.
  static Future<void> signOut() async {
    if (!GoogleAuthConfig.isConfigured) return;
    try {
      await _ensureInitialized();
      await GoogleSignIn.instance.signOut();
    } catch (error) {
      debugPrint('Google sign-out failed: $error');
    }
  }

  static Exception _explain(GoogleSignInException error) {
    final description = error.description ?? '';
    debugPrint('Google sign-in failed: ${error.code} $description ${error.details ?? ''}');
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
        // Also what Credential Manager reports for some setup mistakes (a
        // missing SHA-1): see docs/google_sign_in.md if the picker closes
        // by itself.
        return const GoogleSignInCancelled();
      case GoogleSignInExceptionCode.interrupted:
        return Exception('Google sign-in was interrupted. Please try again.');
      case GoogleSignInExceptionCode.providerConfigurationError:
        // Android: Google Play services missing, disabled or too old.
        return Exception(
          defaultTargetPlatform == TargetPlatform.android
              ? 'Google sign-in needs an up-to-date Google Play services. Update it from the Play Store, then try again.'
              : 'Google sign-in is not available on this device.',
        );
      case GoogleSignInExceptionCode.clientConfigurationError:
        return Exception('Google sign-in is not set up correctly in this version of the app.');
      case GoogleSignInExceptionCode.uiUnavailable:
        return Exception('Could not open Google sign-in. Please try again.');
      default:
        // unknownError, userMismatch, and any code a later version adds.
        break;
    }
    // Android's Credential Manager has no account to offer.
    if (description.startsWith('No credential available')) {
      return Exception('There is no Google account on this device. Add one in your phone\'s Settings, then try again.');
    }
    // Credential Manager's "[28444] Developer console is not set up
    // correctly": this build's package name + SHA-1 is not registered.
    if (description.contains('28444') || description.toLowerCase().contains('developer console')) {
      return Exception('Google sign-in is not set up correctly in this version of the app.');
    }
    return Exception('Google sign-in failed. Check your connection and try again.');
  }
}
