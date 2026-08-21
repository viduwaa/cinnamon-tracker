import "package:flutter_riverpod/flutter_riverpod.dart";
import "../api/api_client.dart";

/// Authenticated user profile.
class UserProfile {
  UserProfile({
    required this.id,
    required this.name,
    required this.mobile,
    required this.roles,
    this.email,
  });

  final String id;
  final String name;
  final String mobile;
  final List<String> roles;
  final String? email;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json["id"].toString(),
        name: json["name"].toString(),
        mobile: json["mobile"].toString(),
        roles: (json["roles"] as List? ?? const []).map((e) => e.toString()).toList(),
        email: json["email"]?.toString(),
      );
}

/// Auth states: signedOut -> otpSent -> signedIn.
sealed class AuthState {}

class SignedOut extends AuthState {}

class OtpSent extends AuthState {
  OtpSent(this.mobile);
  final String mobile;
}

class SignedIn extends AuthState {
  SignedIn(this.user, this.token);
  final UserProfile user;
  final String token;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._api) : super(SignedOut());

  final ApiClient _api;

  Future<void> register({
    required String name,
    required String mobile,
    required List<String> roles,
    String? email,
  }) async {
    await _api.post("/auth/register", body: {
      "name": name,
      "mobile": mobile,
      "email": email,
      "roles": roles,
      "preferred_lang": "si",
    });
  }

  Future<void> requestOtp(String mobile) async {
    await _api.post("/auth/otp/request", body: {"mobile": mobile});
    state = OtpSent(mobile);
  }

  Future<void> verifyOtp(String mobile, String code) async {
    final data = await _api.post(
      "/auth/otp/verify",
      body: {"mobile": mobile, "code": code},
    ) as Map<String, dynamic>;
    final user = UserProfile.fromJson(data["user"] as Map<String, dynamic>);
    state = SignedIn(user, data["token"].toString());
  }

  String? get token {
    final s = state;
    return s is SignedIn ? s.token : null;
  }

  void signOut() => state = SignedOut();
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final auth = ref.read(authProvider.notifier);
  return ApiClient(tokenProvider: () => auth.token);
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ApiClient()),
);

/// The role the user is currently acting as (for multi-role users).
final activeRoleProvider = StateProvider<String>((ref) => "FARMER");
