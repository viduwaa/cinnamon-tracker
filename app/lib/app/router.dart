import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../core/auth/auth_state.dart";
import "../features/auth/login_screen.dart";
import "../features/auth/otp_screen.dart";
import "../features/auth/register_screen.dart";
import "../features/batches/batch_detail_screen.dart";
import "../features/batches/batches_screen.dart";
import "../features/farms/farm_wizard_screen.dart";
import "../features/harvest/harvest_wizard_screen.dart";
import "../features/harvest/harvest_done_screen.dart";
import "../features/home/home_screen.dart";
import "../features/inbox/inbox_screen.dart";
import "../features/qr/qr_screen.dart";
import "../features/settings/settings_screen.dart";
import "../features/shell/app_shell.dart";
import "../features/shell/boot_screen.dart";
import "../features/transfer/transfer_screen.dart";

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: "/boot",
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      // Hold on /boot until the persisted session has been restored.
      if (auth is AuthRestoring) {
        return state.matchedLocation == "/boot" ? null : "/boot";
      }
      final signedIn = auth is SignedIn;
      final atAuth = state.matchedLocation == "/login" ||
          state.matchedLocation == "/register" ||
          state.matchedLocation == "/otp";
      // Returning users are the default path — land them on /login.
      if (!signedIn && !atAuth) return "/login";
      if (signedIn && atAuth) return "/home";
      if (auth is SignedIn && state.matchedLocation.startsWith("/harvest")) {
        final activeRole = ref.read(activeRoleProvider);
        final userRoles = auth.user.roles;
        if (!userRoles.contains("FARMER") || activeRole != "FARMER") {
          return "/home";
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: "/boot",
        builder: (context, state) =>
            const BootScreen(key: ValueKey("boot_screen")),
      ),
      GoRoute(
        path: "/login",
        builder: (context, state) =>
            const LoginScreen(key: ValueKey("login_screen")),
      ),
      GoRoute(
        path: "/register",
        builder: (context, state) =>
            const RegisterScreen(key: ValueKey("register_screen")),
      ),
      GoRoute(
        path: "/otp",
        builder: (context, state) =>
            const OtpScreen(key: ValueKey("otp_screen")),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: "/home", builder: (context, state) => const HomeScreen()),
          GoRoute(path: "/batches", builder: (context, state) => const BatchesScreen()),
          GoRoute(
            path: "/batch/:id",
            builder: (context, state) =>
                BatchDetailScreen(batchId: state.pathParameters["id"]!),
          ),
          GoRoute(path: "/inbox", builder: (context, state) => const InboxScreen()),
          GoRoute(path: "/qr", builder: (context, state) => const QrScreen()),
          GoRoute(
            path: "/qr/show/:batchId",
            builder: (context, state) =>
                QrShowScreen(batchId: state.pathParameters["batchId"]!),
          ),
        ],
      ),
      GoRoute(path: "/harvest", builder: (context, state) => const HarvestWizardScreen()),
      GoRoute(
        path: "/harvest/done/:batchId",
        builder: (context, state) =>
            HarvestDoneScreen(batchId: state.pathParameters["batchId"]!),
      ),
      GoRoute(
        path: "/transfer/:id",
        builder: (context, state) =>
            TransferScreen(batchId: state.pathParameters["id"]!),
      ),
      GoRoute(path: "/farm/new", builder: (context, state) => const FarmWizardScreen()),
      GoRoute(path: "/settings", builder: (context, state) => const SettingsScreen()),
    ],
  );
});

/// Bridges Riverpod auth changes into GoRouter's refreshListenable.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._ref) {
    _sub = _ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.runtimeType != next.runtimeType) {
        notifyListeners();
      }
    });
  }

  final Ref _ref;
  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
