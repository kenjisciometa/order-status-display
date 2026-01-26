import 'user.dart';

/// Authentication status enum
enum AuthStatus {
  /// Initial state, determining auth status
  unknown,

  /// User logged in
  authenticated,

  /// User logged out or login failed
  unauthenticated,

  /// Authentication operation in progress
  loading,
}

/// Authentication state
class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  const AuthState._({
    required this.status,
    this.user,
    this.errorMessage,
  });

  /// Unknown state - initial state
  const AuthState.unknown()
      : status = AuthStatus.unknown,
        user = null,
        errorMessage = null;

  /// Authenticated state
  const AuthState.authenticated(User this.user)
      : status = AuthStatus.authenticated,
        errorMessage = null;

  /// Unauthenticated state
  const AuthState.unauthenticated([this.errorMessage])
      : status = AuthStatus.unauthenticated,
        user = null;

  /// Loading state
  const AuthState.loading()
      : status = AuthStatus.loading,
        user = null,
        errorMessage = null;

  /// Check if user is authenticated
  bool get isAuthenticated => status == AuthStatus.authenticated;

  /// Check if user is unauthenticated
  bool get isUnauthenticated => status == AuthStatus.unauthenticated;

  /// Check if loading
  bool get isLoading => status == AuthStatus.loading;

  /// Check if unknown (initial state)
  bool get isUnknown => status == AuthStatus.unknown;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
  }) {
    return AuthState._(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthState &&
        other.status == status &&
        other.user?.id == user?.id &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => Object.hash(status, user?.id, errorMessage);

  @override
  String toString() {
    return 'AuthState(status: $status, user: ${user?.email}, error: $errorMessage)';
  }
}
