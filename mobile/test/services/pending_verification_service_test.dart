// ABOUTME: Tests for PendingVerification expiry window
// ABOUTME: Verifies the 24h verify window so the PIN path works on late return

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/pending_verification_service.dart';

void main() {
  group(PendingVerification, () {
    PendingVerification pendingCreatedAgo(Duration age) {
      return PendingVerification(
        deviceCode: 'device123',
        verifier: 'verifier456',
        email: 'test@example.com',
        createdAt: DateTime.now().subtract(age),
      );
    }

    test('expiration window is 24 hours', () {
      expect(PendingVerification.expirationDuration, const Duration(hours: 24));
    });

    test('is not expired well within the 24h verify window', () {
      expect(pendingCreatedAgo(const Duration(hours: 23)).isExpired, isFalse);
    });

    test('is not expired just before 24h', () {
      expect(
        pendingCreatedAgo(const Duration(hours: 23, minutes: 59)).isExpired,
        isFalse,
      );
    });

    test('is expired after the 24h verify window', () {
      expect(pendingCreatedAgo(const Duration(hours: 25)).isExpired, isTrue);
    });

    test('data older than the previous 30-minute window is still valid', () {
      // Regression guard for the late-return PIN path: a user who returns an
      // hour later must still have the deviceCode + verifier to exchange.
      expect(pendingCreatedAgo(const Duration(hours: 1)).isExpired, isFalse);
    });
  });
}
