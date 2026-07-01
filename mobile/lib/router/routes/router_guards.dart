// ABOUTME: Pure router helper functions shared between route modules and tests
// ABOUTME: Kept dependency-free of app_router.dart so route modules import them cycle-free

import 'package:openvine/screens/auth/email_verification_screen.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/services/pending_verification_service.dart';

/// Rewrites a `/reset-password` deep link to the nested
/// [WelcomeScreen.resetPasswordPath] route, preserving `token` and
/// optional `email` query params.
///
/// Shared by the auth reset-password route redirect and the router-level
/// regression test so both paths produce the same output for the same
/// input. See issue #3156.
String rewriteResetPasswordDeepLink(Uri uri) {
  final token = uri.queryParameters['token'] ?? '';
  final email = uri.queryParameters['email'];
  final buffer = StringBuffer(WelcomeScreen.resetPasswordPath)
    ..write('?token=')
    ..write(Uri.encodeQueryComponent(token));
  if (email != null && email.isNotEmpty) {
    buffer
      ..write('&email=')
      ..write(Uri.encodeQueryComponent(email));
  }
  return buffer.toString();
}

/// Builds the verify-email restore location for a cold start that found an
/// unexpired pending email-verification record, or `null` when there is
/// nothing to restore.
///
/// Used by the app-bootstrap restore step in `main.dart` so a user who killed
/// the app to read their PIN lands back on the polling-mode verification
/// screen instead of Welcome. The `restored=true` flag tells the screen the
/// close / "Start over" affordance is an escape hatch that should clear the
/// persisted record.
String? pendingEmailVerificationRestoreLocation(PendingVerification? pending) {
  if (pending == null || pending.isExpired) return null;
  // The deviceCode and verifier are secrets and must never ride on a URL that
  // could be logged or leaked. Only the (log-redacted) email and the restore
  // flag travel here; the screen rehydrates deviceCode / verifier / inviteCode
  // from the persisted record on the restore path.
  final email = Uri.encodeQueryComponent(pending.email);
  return '${EmailVerificationScreen.path}?email=$email&restored=true';
}

int homeInitialIndexFromPathParameters(Map<String, String> pathParameters) {
  final rawIndex = int.tryParse(pathParameters['index'] ?? '') ?? 0;
  return rawIndex < 0 ? 0 : rawIndex;
}
