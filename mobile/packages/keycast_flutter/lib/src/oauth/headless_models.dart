// ABOUTME: Response models for headless authentication API
// ABOUTME: Supports native login/register flows without browser redirects

/// Result from POST /api/headless/register
class HeadlessRegisterResult {
  HeadlessRegisterResult({
    required this.success,
    required this.pubkey,
    required this.verificationRequired,
    this.deviceCode,
    this.email,
    this.errorCode,
    this.errorDescription,
  });

  factory HeadlessRegisterResult.fromJson(Map<String, dynamic> json) {
    return HeadlessRegisterResult(
      success: json['success'] as bool? ?? false,
      pubkey: json['pubkey'] as String? ?? '',
      verificationRequired: json['verification_required'] as bool? ?? true,
      deviceCode: json['device_code'] as String?,
      email: json['email'] as String?,
      errorCode: json['error'] as String?,
      errorDescription:
          json['error_description'] as String? ?? json['message'] as String?,
    );
  }

  factory HeadlessRegisterResult.error(String message, {String? code}) {
    return HeadlessRegisterResult(
      success: false,
      pubkey: '',
      verificationRequired: false,
      errorCode: code ?? 'client_error',
      errorDescription: message,
    );
  }
  final bool success;
  final String pubkey;
  final bool verificationRequired;
  final String? deviceCode;
  final String? email;

  /// OAuth error code (e.g., 'email_exists', 'invalid_password')
  final String? errorCode;

  /// Human-readable error description from server
  final String? errorDescription;
}

/// Result from POST /api/headless/login
class HeadlessLoginResult {
  HeadlessLoginResult({
    required this.success,
    this.code,
    this.pubkey,
    this.state,
    this.error,
    this.errorDescription,
  });

  factory HeadlessLoginResult.fromJson(Map<String, dynamic> json) {
    return HeadlessLoginResult(
      success: json['success'] as bool? ?? false,
      code: json['code'] as String?,
      pubkey: json['pubkey'] as String?,
      state: json['state'] as String?,
      error: json['error'] as String?,
      errorDescription: json['error_description'] as String?,
    );
  }

  factory HeadlessLoginResult.error(String message, {String? code}) {
    return HeadlessLoginResult(
      success: false,
      error: code ?? 'client_error',
      errorDescription: message,
    );
  }
  final bool success;
  final String? code;
  final String? pubkey;
  final String? state;
  final String? error;
  final String? errorDescription;
}

/// Result from GET /api/oauth/poll
enum KeycastAuthFailure {
  emailAlreadyRegistered,
  expiredVerification,
  temporary,
  network,
  unknown,
}

class PollResult {
  PollResult({
    required this.status,
    this.code,
    this.error,
    this.errorCode,
    this.statusCode,
    this.failure,
  });

  factory PollResult.pending() => PollResult(status: PollStatus.pending);

  factory PollResult.complete(String code) =>
      PollResult(status: PollStatus.complete, code: code);

  factory PollResult.error(
    String message, {
    String? errorCode,
    int? statusCode,
    KeycastAuthFailure failure = KeycastAuthFailure.unknown,
  }) => PollResult(
    status: PollStatus.error,
    error: message,
    errorCode: errorCode,
    statusCode: statusCode,
    failure: failure,
  );
  final PollStatus status;
  final String? code;
  final String? error;
  final String? errorCode;
  final int? statusCode;
  final KeycastAuthFailure? failure;

  bool get isTransientFailure =>
      failure == KeycastAuthFailure.network ||
      failure == KeycastAuthFailure.temporary;
}

enum PollStatus {
  pending, // Still waiting for email verification
  complete, // User verified, code available
  error, // Something went wrong
}

/// Reason a [VerifyPinResult] failed.
///
/// keycast intentionally returns uniform anti-enumeration errors, so the
/// server may collapse several of these into one generic failure. Callers
/// should treat distinct cases as advisory and fall back to generic copy.
enum VerifyPinError {
  /// The submitted PIN was incorrect.
  invalid,

  /// The PIN (or its 24h verification window) has expired.
  expired,

  /// Too many failed attempts — the PIN is locked until a new one is sent.
  locked,

  /// Transient network error or timeout.
  network,

  /// Server returned a 5xx or otherwise unexpected/malformed response.
  server,
}

/// Result from POST /api/headless/verify-pin
class VerifyPinResult {
  final bool success;

  /// OAuth authorization code, returned synchronously on success.
  final String? code;

  /// Reason code on failure (null on success).
  final VerifyPinError? errorCode;

  /// Human-readable description from the server, for logs only — never shown
  /// to the user (the UI localizes [errorCode]).
  final String? errorDescription;

  VerifyPinResult({
    required this.success,
    this.code,
    this.errorCode,
    this.errorDescription,
  });

  factory VerifyPinResult.success(String code) =>
      VerifyPinResult(success: true, code: code);

  factory VerifyPinResult.failure(
    VerifyPinError errorCode, {
    String? description,
  }) => VerifyPinResult(
    success: false,
    errorCode: errorCode,
    errorDescription: description,
  );
}

/// Result from POST /api/auth/resend-verification
class ResendVerificationResult {
  final bool success;
  final String? message;

  ResendVerificationResult({required this.success, this.message});

  factory ResendVerificationResult.fromJson(Map<String, dynamic> json) {
    return ResendVerificationResult(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }

  factory ResendVerificationResult.failure() =>
      ResendVerificationResult(success: false);
}

/// Result from POST /api/auth/forgot-password
class ForgotPasswordResult {
  ForgotPasswordResult({required this.success, this.message, this.error});

  factory ForgotPasswordResult.fromJson(Map<String, dynamic> json) {
    return ForgotPasswordResult(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      error: json['error'] as String?,
    );
  }

  factory ForgotPasswordResult.error(String message) {
    return ForgotPasswordResult(success: false, error: message);
  }
  final bool success;
  final String? message;
  final String? error;
}

class ResetPasswordResult {
  ResetPasswordResult({required this.success, this.message});

  factory ResetPasswordResult.fromJson(Map<String, dynamic> json) {
    return ResetPasswordResult(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }

  factory ResetPasswordResult.error(String message) {
    return ResetPasswordResult(success: false, message: message);
  }
  final bool success;
  final String? message;
}

/// Result from DELETE /api/user/account
class DeleteAccountResult {
  DeleteAccountResult({required this.success, this.message, this.error});

  factory DeleteAccountResult.fromJson(Map<String, dynamic> json) {
    return DeleteAccountResult(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      error: json['error'] as String?,
    );
  }

  factory DeleteAccountResult.error(String message) {
    return DeleteAccountResult(success: false, error: message);
  }
  final bool success;
  final String? message;
  final String? error;
}

/// Result from POST /api/auth/verify-email
class VerifyEmailResult {
  VerifyEmailResult({
    required this.success,
    this.message,
    this.error,
    this.errorCode,
    this.statusCode,
    this.failure,
  });

  factory VerifyEmailResult.fromJson(
    Map<String, dynamic> json, {
    int? statusCode,
  }) {
    return VerifyEmailResult(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      error: json['error'] as String?,
      errorCode: json['code'] as String?,
      statusCode: statusCode,
    );
  }

  factory VerifyEmailResult.error(
    String message, {
    String? errorCode,
    int? statusCode,
    KeycastAuthFailure failure = KeycastAuthFailure.unknown,
  }) => VerifyEmailResult(
    success: false,
    error: message,
    errorCode: errorCode,
    statusCode: statusCode,
    failure: failure,
  );
  final bool success;
  final String? message;
  final String? error;
  final String? errorCode;
  final int? statusCode;
  final KeycastAuthFailure? failure;

  bool get isTransientFailure =>
      failure == KeycastAuthFailure.network ||
      failure == KeycastAuthFailure.temporary;
}
