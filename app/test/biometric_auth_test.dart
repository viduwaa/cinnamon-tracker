import "package:cinnamon_trace/core/auth/auth_state.dart";
import "package:cinnamon_trace/core/auth/biometric_service.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:flutter_test/flutter_test.dart";
import "package:local_auth/local_auth.dart";

class FakeBiometricAuth extends Fake implements LocalAuthentication {
  bool supported = true;
  bool canCheck = true;
  bool authResult = true;
  List<BiometricType> biometrics = [BiometricType.fingerprint];

  @override
  Future<bool> isDeviceSupported() async => supported;

  @override
  Future<bool> get canCheckBiometrics async => canCheck;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => biometrics;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<dynamic>? authMessages,
    AuthenticationOptions? options,
  }) async => authResult;

  @override
  Future<bool> stopAuthentication() async => true;
}

class FakeStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _map = {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #read) {
      final key = invocation.namedArguments[#key] as String;
      return Future.value(_map[key]);
    }
    if (invocation.memberName == #write) {
      final key = invocation.namedArguments[#key] as String;
      final value = invocation.namedArguments[#value] as String?;
      if (value != null) {
        _map[key] = value;
      } else {
        _map.remove(key);
      }
      return Future.value();
    }
    if (invocation.memberName == #delete) {
      final key = invocation.namedArguments[#key] as String;
      _map.remove(key);
      return Future.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class FakeAuthRepo extends Fake implements AuthRepository {
  MapEntry<String, UserProfile>? savedSession;
  bool cleared = false;

  @override
  Future<void> save(String token, UserProfile user) async {
    savedSession = MapEntry(token, user);
  }

  @override
  Future<MapEntry<String, UserProfile>?> load() async {
    return savedSession;
  }

  @override
  Future<void> clear() async {
    savedSession = null;
    cleared = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("BiometricService & BiometricState", () {
    test("BiometricService detects hardware and manages preference", () async {
      final fakeAuth = FakeBiometricAuth();
      final fakeStorage = FakeStorage();
      final service = BiometricService(auth: fakeAuth, storage: fakeStorage);

      expect(await service.isDeviceSupported(), isTrue);
      expect(await service.getAvailableBiometrics(), [BiometricType.fingerprint]);
      expect(await service.isBiometricEnabled(), isFalse);

      await service.setBiometricEnabled(true);
      expect(await service.isBiometricEnabled(), isTrue);

      final authSuccess = await service.authenticate();
      expect(authSuccess, isTrue);

      await service.setBiometricEnabled(false);
      expect(await service.isBiometricEnabled(), isFalse);
    });

    test("BiometricNotifier manages state transitions", () async {
      final fakeAuth = FakeBiometricAuth();
      final fakeStorage = FakeStorage();
      final service = BiometricService(auth: fakeAuth, storage: fakeStorage);
      final notifier = BiometricNotifier(service);

      await notifier.refresh();
      expect(notifier.state.isSupported, isTrue);
      expect(notifier.state.isEnabled, isFalse);

      final enabled = await notifier.enableBiometrics();
      expect(enabled, isTrue);
      expect(notifier.state.isEnabled, isTrue);

      await notifier.disableBiometrics();
      expect(notifier.state.isEnabled, isFalse);
    });
  });

  group("AuthNotifier with Biometric Lock", () {
    test("restores into SessionLocked when session exists and biometrics is enabled", () async {
      final fakeAuth = FakeBiometricAuth();
      final fakeStorage = FakeStorage();
      final service = BiometricService(auth: fakeAuth, storage: fakeStorage);
      await service.setBiometricEnabled(true);

      final fakeRepo = FakeAuthRepo();
      final testUser = UserProfile(
        id: "u123",
        name: "Sunil Silva",
        mobile: "+94771234567",
        roles: ["FARMER"],
      );
      await fakeRepo.save("jwt_token_123", testUser);

      final authNotifier = AuthNotifier(fakeRepo, service);
      // Wait for async _restore()
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(authNotifier.state, isA<SessionLocked>());
      final locked = authNotifier.state as SessionLocked;
      expect(locked.user.name, "Sunil Silva");
      expect(locked.token, "jwt_token_123");
      expect(authNotifier.token, "jwt_token_123");

      // Unlock with biometrics
      final unlocked = await authNotifier.unlockWithBiometrics();
      expect(unlocked, isTrue);
      expect(authNotifier.state, isA<SignedIn>());
    });

    test("unlockSession transitions SessionLocked to SignedIn", () async {
      final fakeAuth = FakeBiometricAuth();
      final fakeStorage = FakeStorage();
      final service = BiometricService(auth: fakeAuth, storage: fakeStorage);
      await service.setBiometricEnabled(true);

      final fakeRepo = FakeAuthRepo();
      final testUser = UserProfile(
        id: "u123",
        name: "Sunil Silva",
        mobile: "+94771234567",
        roles: ["FARMER"],
      );
      await fakeRepo.save("jwt_token_123", testUser);

      final authNotifier = AuthNotifier(fakeRepo, service);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(authNotifier.state, isA<SessionLocked>());
      authNotifier.unlockSession();
      expect(authNotifier.state, isA<SignedIn>());
    });

    test("signOut clears repository and disables biometrics", () async {
      final fakeAuth = FakeBiometricAuth();
      final fakeStorage = FakeStorage();
      final service = BiometricService(auth: fakeAuth, storage: fakeStorage);
      await service.setBiometricEnabled(true);

      final fakeRepo = FakeAuthRepo();
      final testUser = UserProfile(
        id: "u123",
        name: "Sunil Silva",
        mobile: "+94771234567",
        roles: ["FARMER"],
      );
      await fakeRepo.save("jwt_token_123", testUser);

      final authNotifier = AuthNotifier(fakeRepo, service);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await authNotifier.signOut();
      expect(authNotifier.state, isA<SignedOut>());
      expect(fakeRepo.cleared, isTrue);
      expect(await service.isBiometricEnabled(), isFalse);
    });
  });
}
