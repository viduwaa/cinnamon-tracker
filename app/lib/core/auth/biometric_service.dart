import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:local_auth/local_auth.dart";

/// Service for device biometric authentication (Fingerprint, Face ID, etc.)
class BiometricService {
  BiometricService({
    LocalAuthentication? auth,
    FlutterSecureStorage? storage,
  })  : _auth = auth ?? LocalAuthentication(),
        _storage = storage ?? const FlutterSecureStorage();

  final LocalAuthentication _auth;
  final FlutterSecureStorage _storage;

  static const _biometricEnabledKey = "ct.biometrics_enabled";

  /// Returns true if hardware exists and device has enrolled biometrics.
  Future<bool> isDeviceSupported() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return isSupported && canCheck;
    } catch (_) {
      return false;
    }
  }

  /// Returns list of available biometric sensors on the device.
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return const [];
    }
  }

  /// Checks if the user has enabled biometric login in Cinnamon Trace.
  Future<bool> isBiometricEnabled() async {
    try {
      final val = await _storage.read(key: _biometricEnabledKey);
      return val == "true";
    } catch (_) {
      return false;
    }
  }

  /// Saves the biometric login preference.
  Future<void> setBiometricEnabled(bool enabled) async {
    try {
      if (enabled) {
        await _storage.write(key: _biometricEnabledKey, value: "true");
      } else {
        await _storage.delete(key: _biometricEnabledKey);
      }
    } catch (_) {}
  }

  /// Prompts the system biometric scanner.
  Future<bool> authenticate({
    String localizedReason = "Scan fingerprint to access Cinnamon Trace",
    bool biometricOnly = true,
  }) async {
    try {
      final isSupported = await isDeviceSupported();
      if (!isSupported) return false;

      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: biometricOnly,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

/// State of biometric support and user preference.
class BiometricState {
  const BiometricState({
    required this.isSupported,
    required this.isEnabled,
    required this.availableBiometrics,
    this.isLoading = false,
  });

  final bool isSupported;
  final bool isEnabled;
  final List<BiometricType> availableBiometrics;
  final bool isLoading;

  BiometricState copyWith({
    bool? isSupported,
    bool? isEnabled,
    List<BiometricType>? availableBiometrics,
    bool? isLoading,
  }) {
    return BiometricState(
      isSupported: isSupported ?? this.isSupported,
      isEnabled: isEnabled ?? this.isEnabled,
      availableBiometrics: availableBiometrics ?? this.availableBiometrics,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class BiometricNotifier extends StateNotifier<BiometricState> {
  BiometricNotifier(this._service)
      : super(const BiometricState(
          isSupported: false,
          isEnabled: false,
          availableBiometrics: [],
          isLoading: true,
        )) {
    refresh();
  }

  final BiometricService _service;

  Future<void> refresh() async {
    final supported = await _service.isDeviceSupported();
    final enabled = await _service.isBiometricEnabled();
    final biometrics = supported ? await _service.getAvailableBiometrics() : <BiometricType>[];
    if (!mounted) return;
    state = BiometricState(
      isSupported: supported,
      isEnabled: enabled && supported,
      availableBiometrics: biometrics,
      isLoading: false,
    );
  }

  /// Prompts user to scan their fingerprint to verify and turn ON biometric login.
  Future<bool> enableBiometrics() async {
    final authenticated = await _service.authenticate(
      localizedReason: "Confirm your fingerprint to enable biometric login\nඇඟිලි සලකුණු පිවිසුම සක්‍රිය කිරීමට තහවුරු කරන්න",
    );
    if (authenticated) {
      await _service.setBiometricEnabled(true);
      await refresh();
      return true;
    }
    return false;
  }

  /// Disables biometric login without requiring biometric confirmation.
  Future<void> disableBiometrics() async {
    await _service.setBiometricEnabled(false);
    await refresh();
  }

  /// General authentication prompt for app unlocking.
  Future<bool> authenticate({String? localizedReason}) async {
    return await _service.authenticate(
      localizedReason: localizedReason ??
          "Scan fingerprint to unlock Cinnamon Trace\nකුරුඳු සලකුණ වෙත පිවිසීමට ඇඟිලි සලකුණ තහවුරු කරන්න",
    );
  }
}

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

final biometricProvider = StateNotifierProvider<BiometricNotifier, BiometricState>((ref) {
  return BiometricNotifier(ref.watch(biometricServiceProvider));
});
