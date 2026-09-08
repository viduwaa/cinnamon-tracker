import "dart:convert";

import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";

import "../api/api_client.dart";
import "../db/app_database.dart";

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

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "mobile": mobile,
        "roles": roles,
        "email": email,
      };
}

/// Auth states: restoring (boot) -> signedOut -> otpSent -> signedIn.
sealed class AuthState {}

/// Initial state while the persisted session is being restored from secure
/// storage + MetaKv. The router holds on /boot until this resolves.
class AuthRestoring extends AuthState {}

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

/// Persists the session: JWT in flutter_secure_storage, profile JSON in the
/// drift MetaKv table (flutter-plan §3.1 — the JWT never touches drift).
class AuthRepository {
  AuthRepository(this._db);

  final AppDatabase _db;

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = "ct.jwt";
  static const _profileKey = "auth.profile";

  Future<void> save(String token, UserProfile user) async {
    await _storage.write(key: _tokenKey, value: token);
    await _db.setMeta(_profileKey, jsonEncode(user.toJson()));
  }

  /// Returns (token, user) when a complete session is stored, else null.
  Future<MapEntry<String, UserProfile>?> load() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token == null || token.isEmpty) return null;
      final profileJson = await _db.getMeta(_profileKey);
      if (profileJson == null) return null;
      return MapEntry(
        token,
        UserProfile.fromJson(jsonDecode(profileJson) as Map<String, dynamic>),
      );
    } catch (_) {
      // Corrupt or unreadable storage → treat as signed out.
      return null;
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _db.removeMeta(_profileKey);
    await _db.purgeSyncedData();
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repo, [ApiClient? api]) : super(AuthRestoring()) {
    _api = api ?? ApiClient(tokenProvider: () => token);
    _restore();
  }

  late final ApiClient _api;
  final AuthRepository _repo;

  /// Restores a persisted session without touching the network: if a token
  /// exists, the user goes straight to SignedIn using the cached profile.
  Future<void> _restore() async {
    try {
      final saved = await _repo.load();
      if (!mounted) return;
      state = saved == null ? SignedOut() : SignedIn(saved.value, saved.key);
    } catch (_) {
      // Storage failure must still resolve the boot state (never stay
      // AuthRestoring and hold the router on /boot forever).
      if (!mounted) return;
      state = SignedOut();
    }
  }

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
    final token = data["token"].toString();
    final user = UserProfile.fromJson(data["user"] as Map<String, dynamic>);
    await _repo.save(token, user);
    state = SignedIn(user, token);
  }

  String? get token {
    final s = state;
    return s is SignedIn ? s.token : null;
  }

  /// Adds a new role to the authenticated user profile.
  Future<void> addRole(String role) async {
    final s = state;
    if (s is! SignedIn) return;
    final data = await _api.post(
      "/auth/me/roles",
      body: {"role": role},
    ) as Map<String, dynamic>;
    final updatedUser = UserProfile.fromJson(data);
    await _repo.save(s.token, updatedUser);
    state = SignedIn(updatedUser, s.token);
  }

  /// Removes an existing role from the authenticated user profile.
  Future<void> removeRole(String role) async {
    final s = state;
    if (s is! SignedIn) return;
    final data = await _api.delete(
      "/auth/me/roles/$role",
    ) as Map<String, dynamic>;
    final updatedUser = UserProfile.fromJson(data);
    await _repo.save(s.token, updatedUser);
    state = SignedIn(updatedUser, s.token);
  }

  /// Updates profile details (name, email, preferred_lang).
  Future<void> updateProfile({String? name, String? email, String? preferredLang}) async {
    final s = state;
    if (s is! SignedIn) return;
    final payload = <String, dynamic>{};
    if (name != null) payload["name"] = name;
    if (email != null) payload["email"] = email;
    if (preferredLang != null) payload["preferred_lang"] = preferredLang;

    final data = await _api.put(
      "/auth/me",
      body: payload,
    ) as Map<String, dynamic>;
    final updatedUser = UserProfile.fromJson(data);
    await _repo.save(s.token, updatedUser);
    state = SignedIn(updatedUser, s.token);
  }

  Future<void> signOut() async {
    await _repo.clear();
    state = SignedOut();
  }

  /// A 401 from the sync worker: drop the session so the router redirects to
  /// OTP login, but keep ALL local data (drift stays untouched).
  /// Ignored unless SignedIn — while AuthRestoring/OtpSent requests went out
  /// without a token and wiping here would erase a session mid-restore.
  Future<void> sessionExpired() async {
    if (state is! SignedIn) return;
    await _repo.clear();
    state = SignedOut();
  }
}

final authRepoProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(appDatabaseProvider)),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  final auth = ref.read(authProvider.notifier);
  return ApiClient(tokenProvider: () => auth.token);
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.watch(authRepoProvider)),
);

/// The role the user is currently acting as (for multi-role users).
final activeRoleProvider = StateProvider<String>((ref) => "FARMER");
