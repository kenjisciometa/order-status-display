import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Simple DTO for native Google authentication tokens.
class GoogleAuthTokens {
  final String idToken;
  final String accessToken;
  final String? email;

  GoogleAuthTokens({
    required this.idToken,
    required this.accessToken,
    this.email,
  });
}

/// Native Google Sign-In helper for Android.
///
/// This service is intentionally decoupled from Supabase. It only
/// handles the Google OAuth flow and returns the raw tokens so that
/// the backend (React POS) can exchange them for a Supabase session.
class GoogleAuthService {
  static String? get _serverClientId =>
      dotenv.env['GOOGLE_ANDROID_SERVER_CLIENT_ID'];

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // Android専用のClient ID（Google Cloud Consoleで作成済み）
    // .env から取得し、未設定の場合は null を渡して GoogleSignIn に任せる
    serverClientId: _serverClientId,
  );

  /// Execute native Google Sign-In and return ID/Access tokens.
  ///
  /// Returns `null` if the user cancels the sign-in flow.
  static Future<GoogleAuthTokens?> signInAndGetTokens() async {
    // For now, limit native Google Sign-In to Android as per plan.
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'Native Google Sign-In is currently supported on Android only.',
      );
    }

    try {
      // Debug configuration
      if (_serverClientId != null) {
        final id = _serverClientId!;
        final shortId = id.length > 20
            ? '${id.substring(0, 10)}...${id.substring(id.length - 10)}'
            : id;
        debugPrint(
            '🔐 [OSD GOOGLE AUTH] Using serverClientId from .env: $shortId (length: ${id.length})');
      } else {
        debugPrint(
            '⚠️ [OSD GOOGLE AUTH] GOOGLE_ANDROID_SERVER_CLIENT_ID is null - using default GoogleSignIn configuration');
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // User cancelled the sign-in flow.
      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final String? accessToken = googleAuth.accessToken;
      final String? idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        throw Exception(
          'Failed to obtain Google auth tokens. '
          'AccessToken: ${accessToken != null}, IdToken: ${idToken != null}',
        );
      }

      return GoogleAuthTokens(
        idToken: idToken,
        accessToken: accessToken,
        email: googleUser.email,
      );
    } catch (e) {
      // Let callers decide how to surface the error.
      rethrow;
    }
  }

  /// Sign out from Google on the device (does not touch Supabase).
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      rethrow;
    }
  }

  /// Check current Google sign-in status.
  static Future<bool> isSignedIn() async {
    try {
      return await _googleSignIn.isSignedIn();
    } catch (_) {
      return false;
    }
  }

  /// Currently signed in Google user (if any).
  static GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;
}
