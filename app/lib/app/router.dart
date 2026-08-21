import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../core/auth/auth_state.dart";
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
import "../features/shell/app_shell.dart";
import "../features/transfer/transfer_screen.dart";

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: "/register",
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final signedIn = ref.read(authProvider) is SignedIn;
      final atAuth =
          state.matchedLocation == "/register" || state.matchedLocation == "/otp";
      if (!signedIn && !atAuth) return "/register";
      if (signedIn && atAuth) return "/home";
      return null;
    },
    routes: [
      GoRoute(path: "/register", builder: (_, __) => const RegisterScreen()),
      GoRoute(path: "/otp", builder: (_, __) => const OtpScreen()),
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(path: "/home", builder: (_, __) => const HomeScreen()),
          GoRoute(path: "/batches", builder: (_, __) => const BatchesScreen()),
          GoRoute(
            path: "/batch/:id",
            builder: (_, state) =>
                BatchDetailScreen(batchId: state.pathParameters["id"]!),
          ),
          GoRoute(path: "/inbox", builder: (_, __) => const InboxScreen()),
          GoRoute(path: "/qr", builder: (_, __) => const QrScreen()),
          GoRoute(
            path: "/qr/show/:batchId",
            builder: (_, state) =>
                QrShowScreen(batchId: state.pathParameters["batchId"]!),
          ),
        ],
      ),
      GoRoute(path: "/harvest", builder: (_, __) => const HarvestWizardScreen()),
      GoRoute(
        path: "/harvest/done/:batchId",
        builder: (_, state) =>
            HarvestDoneScreen(batchId: state.pathParameters["batchId"]!),
      ),
      GoRoute(
        path: "/transfer/:id",
        builder: (_, state) =>
            TransferScreen(batchId: state.pathParameters["id"]!),
      ),
      GoRoute(path: "/farm/new", builder: (_, __) => const FarmWizardScreen()),
    ],
  );
});

/// Bridges Riverpod auth changes into GoRouter's refreshListenable.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._ref) {
    _sub = _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;
  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
