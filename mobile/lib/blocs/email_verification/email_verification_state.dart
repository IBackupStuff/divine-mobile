// ABOUTME: State for EmailVerificationBloc
// ABOUTME: Tracks polling status, pending email, and error reason code

part of 'email_verification_cubit.dart';

/// Status of email verification polling
enum EmailVerificationStatus {
  /// Not polling
  initial,

  /// Actively polling for verification
  polling,

  /// The 15-minute poll window elapsed without verification, but the screen
  /// stays usable: the user can still enter the emailed PIN (or resend it)
  /// instead of being dropped to a terminal "Start Over" dead end.
  pollingTimedOut,

  /// Verification completed successfully
  success,

  /// Polling failed with an error
  failure,
}

/// Status of an in-app PIN submission, surfaced alongside [polling] /
/// [pollingTimedOut] so PIN feedback never replaces the link/poll affordances.
enum PinSubmissionStatus {
  /// No PIN submission in flight.
  idle,

  /// A PIN is being verified against the server.
  submitting,

  /// The last PIN submission failed; see [EmailVerificationState.pinErrorCode].
  failure,
}

/// Status of the "resend verification email" affordance.
enum ResendStatus {
  /// Resend is available.
  idle,

  /// A resend request is in flight.
  sending,

  /// Resend is on its post-send 5-minute cooldown.
  cooldown,
}

/// Reason codes for a verification failure.
///
/// State must never carry user-facing English strings — the UI layer maps
/// these codes to localized copy via `context.l10n` when rendering.
enum EmailVerificationError {
  /// Polling exceeded the 15 minute timeout.
  timeout,

  /// OAuth completion detected but the authorization code or verifier was
  /// missing from the response.
  missingAuthCode,

  /// OAuth server returned a non-transient error during polling.
  pollFailed,

  /// Token exchange failed with a network error after retries were exhausted.
  networkExchange,

  /// OAuth server rejected the token exchange (invalid / expired code).
  oauthExchange,

  /// Sign-in completed token exchange but left the session unauthenticated.
  signInFailed,

  /// Token-based verification link is expired or no longer valid.
  verificationLinkExpired,

  /// Connection error while verifying via a token link.
  verificationConnectionError,

  /// The verified email already belongs to another account.
  emailAlreadyRegistered,

  /// Invite activation failed because the invite was already used.
  inviteAlreadyUsed,

  /// Invite activation failed because the invite is invalid or revoked.
  inviteInvalid,

  /// Invite activation failed because of a temporary server / network issue.
  inviteTemporary,

  /// Invite activation failed for an unspecified reason.
  inviteUnknown,

  /// The submitted PIN was incorrect.
  pinInvalid,

  /// The submitted PIN (or its verify window) has expired.
  pinExpired,

  /// The PIN is locked after too many failed attempts; a resend is required.
  pinLocked,

  /// PIN verification failed for a network / server / unexpected reason.
  pinFailed,
}

/// State for email verification polling
final class EmailVerificationState extends Equatable {
  const EmailVerificationState({
    this.status = EmailVerificationStatus.initial,
    this.pendingEmail,
    this.errorCode,
    this.showInviteGateRecovery = false,
    this.inviteRecoveryCode,
    this.pinStatus = PinSubmissionStatus.idle,
    this.pinErrorCode,
    this.resendStatus = ResendStatus.idle,
    this.resendCooldownSeconds = 0,
  });

  /// Current polling status
  final EmailVerificationStatus status;

  /// Email address being verified (if polling)
  final String? pendingEmail;

  /// Reason code for the failure (if status is [EmailVerificationStatus.failure]).
  ///
  /// Always `null` on non-failure states. Mapped to a localized string in the
  /// UI layer — never store or render a raw English string here.
  final EmailVerificationError? errorCode;

  /// Whether the failure should send the user back through the invite gate.
  final bool showInviteGateRecovery;

  /// Invite code to prefill when recovering through the invite gate.
  final String? inviteRecoveryCode;

  /// Status of the in-app PIN submission.
  final PinSubmissionStatus pinStatus;

  /// Reason code for the last PIN failure. Read by the UI only when
  /// [pinStatus] is [PinSubmissionStatus.failure]; mapped to localized copy
  /// the same way as [errorCode] — never a raw English string.
  final EmailVerificationError? pinErrorCode;

  /// Status of the resend-verification affordance.
  final ResendStatus resendStatus;

  /// Seconds remaining on the resend cooldown (0 when [resendStatus] is not
  /// [ResendStatus.cooldown]).
  final int resendCooldownSeconds;

  /// Whether currently polling
  bool get isPolling => status == EmailVerificationStatus.polling;

  EmailVerificationState copyWith({
    EmailVerificationStatus? status,
    String? pendingEmail,
    EmailVerificationError? errorCode,
    bool? showInviteGateRecovery,
    String? inviteRecoveryCode,
    PinSubmissionStatus? pinStatus,
    EmailVerificationError? pinErrorCode,
    ResendStatus? resendStatus,
    int? resendCooldownSeconds,
  }) {
    return EmailVerificationState(
      status: status ?? this.status,
      pendingEmail: pendingEmail ?? this.pendingEmail,
      errorCode: errorCode,
      showInviteGateRecovery:
          showInviteGateRecovery ?? this.showInviteGateRecovery,
      inviteRecoveryCode: inviteRecoveryCode ?? this.inviteRecoveryCode,
      pinStatus: pinStatus ?? this.pinStatus,
      pinErrorCode: pinErrorCode ?? this.pinErrorCode,
      resendStatus: resendStatus ?? this.resendStatus,
      resendCooldownSeconds:
          resendCooldownSeconds ?? this.resendCooldownSeconds,
    );
  }

  @override
  List<Object?> get props => [
    status,
    pendingEmail,
    errorCode,
    showInviteGateRecovery,
    inviteRecoveryCode,
    pinStatus,
    pinErrorCode,
    resendStatus,
    resendCooldownSeconds,
  ];
}
