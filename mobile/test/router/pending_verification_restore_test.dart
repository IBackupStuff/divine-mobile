// ABOUTME: Unit tests for pendingEmailVerificationRestoreLocation
// ABOUTME: Pure PendingVerification -> verify-email restore URL mapping

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/services/pending_verification_service.dart';

PendingVerification _pending({
  String deviceCode = 'device-123',
  String verifier = 'verifier-abc',
  String email = 'user@example.com',
  DateTime? createdAt,
}) {
  return PendingVerification(
    deviceCode: deviceCode,
    verifier: verifier,
    email: email,
    createdAt: createdAt ?? DateTime.now(),
  );
}

void main() {
  group('pendingEmailVerificationRestoreLocation', () {
    test('returns null when there is no pending record', () {
      expect(pendingEmailVerificationRestoreLocation(null), isNull);
    });

    test('returns null when the pending record has expired', () {
      final expired = _pending(
        createdAt: DateTime.now().subtract(const Duration(hours: 25)),
      );
      expect(pendingEmailVerificationRestoreLocation(expired), isNull);
    });

    test('builds a restore URL with only email + restored flag', () {
      final location = pendingEmailVerificationRestoreLocation(_pending());
      expect(location, isNotNull);

      final uri = Uri.parse(location!);
      expect(uri.path, equals('/verify-email'));
      expect(uri.queryParameters['email'], equals('user@example.com'));
      expect(uri.queryParameters['restored'], equals('true'));
    });

    test('does not put the deviceCode or verifier secrets in the URL', () {
      final location = pendingEmailVerificationRestoreLocation(_pending());
      // deviceCode/verifier are secrets and are rehydrated from the persisted
      // record on the restore path, never carried on a URL that could be
      // logged or leaked.
      expect(location, isNot(contains('device-123')));
      expect(location, isNot(contains('verifier-abc')));
      final uri = Uri.parse(location!);
      expect(uri.queryParameters.containsKey('deviceCode'), isFalse);
      expect(uri.queryParameters.containsKey('verifier'), isFalse);
    });

    test('percent-encodes the email so the URL round-trips', () {
      final location = pendingEmailVerificationRestoreLocation(
        _pending(email: 'a+b@example.com'),
      );
      final uri = Uri.parse(location!);
      expect(uri.queryParameters['email'], equals('a+b@example.com'));
    });
  });
}
