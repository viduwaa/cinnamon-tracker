import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../app/theme.dart";
import "../../core/auth/auth_state.dart";
import "../../core/widgets/ct_widgets.dart";

class BiometricLockScreen extends ConsumerStatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  ConsumerState<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends ConsumerState<BiometricLockScreen> {
  bool _authenticating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _promptBiometric();
    });
  }

  Future<void> _promptBiometric() async {
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _errorMessage = null;
    });

    try {
      final success = await ref.read(authProvider.notifier).unlockWithBiometrics();
      if (!mounted) return;
      if (!success) {
        setState(() {
          _errorMessage = "Fingerprint not recognized. Tap to try again.";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Authentication failed: ${e.toString()}";
        });
      }
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  Future<void> _fallbackToLogin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ct.radius)),
        title: Text("Switch Account?", style: Theme.of(context).textTheme.titleLarge),
        content: const Text(
          "This will lock the current session and take you to the mobile login screen.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          CtButton(
            label: "Log in with phone",
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final text = Theme.of(context).textTheme;

    final user = auth is SessionLocked ? auth.user : null;
    final userName = user?.name.trim().isNotEmpty == true ? user!.name : "User";
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : "?";

    return CtDoubleBackExit(
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Ct.pad, vertical: 24),
            child: Column(
              children: [
                const SizedBox(height: 12),
                // App Logo
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Ct.cinnamon,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.spa_outlined, color: Ct.cream, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Cinnamon Trace",
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFamily: Ct.display,
                          ),
                        ),
                        Text(
                          "කුරුඳු සලකුණ",
                          style: text.labelSmall?.copyWith(color: Ct.faded),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(flex: 2),

                // User profile avatar & greeting
                CircleAvatar(
                  radius: 38,
                  backgroundColor: Ct.cinnamon,
                  child: Text(
                    userInitial,
                    style: text.headlineLarge?.copyWith(
                      color: Ct.paper,
                      fontFamily: Ct.display,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Welcome back,",
                  style: text.bodyLarge?.copyWith(color: Ct.faded),
                ),
                Text(
                  userName,
                  style: text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (user?.mobile != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    user!.mobile,
                    style: text.bodySmall?.copyWith(color: Ct.faded),
                  ),
                ],
                const Spacer(flex: 2),

                // Interactive Fingerprint Trigger
                GestureDetector(
                  onTap: _authenticating ? null : _promptBiometric,
                  child: Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      color: Ct.cinnamon.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _errorMessage != null
                            ? Ct.clay
                            : Ct.cinnamon.withValues(alpha: 0.35),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Ct.cinnamon.withValues(alpha: 0.08),
                          blurRadius: 18,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: _authenticating
                          ? const SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Ct.cinnamon,
                              ),
                            )
                          : Icon(
                              Icons.fingerprint_rounded,
                              size: 64,
                              color: _errorMessage != null ? Ct.clay : Ct.cinnamon,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Touch the fingerprint sensor to unlock",
                  textAlign: TextAlign.center,
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  "ඇඟිලි සලකුණ භාවිතයෙන් අගුළු හරින්න",
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: Ct.faded),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Ct.claySoft,
                      borderRadius: BorderRadius.circular(Ct.radiusSm),
                      border: Border.all(color: Ct.clay.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: text.bodySmall?.copyWith(
                        color: Ct.clay,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const Spacer(flex: 3),

                // Fallback action to sign in with phone number
                TextButton.icon(
                  onPressed: _fallbackToLogin,
                  icon: const Icon(Icons.phone_android, size: 20, color: Ct.faded),
                  label: Text(
                    "Log in with phone number  ·  දුරකථන අංකයෙන් පිවිසෙන්න",
                    style: text.labelMedium?.copyWith(
                      color: Ct.faded,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
