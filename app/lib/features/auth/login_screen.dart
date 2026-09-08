import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../app/theme.dart";
import "../../core/auth/auth_state.dart";
import "../../core/widgets/ct_widgets.dart";
import "../../core/widgets/phone_input_field.dart";

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _mobile = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _notRegistered = false;

  @override
  void dispose() {
    _mobile.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final mobile = normalizePhoneNumber(_mobile.text);
    if (mobile.length < 8) {
      setState(() => _error = "Please enter a valid mobile number");
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _notRegistered = false;
    });
    try {
      await ref.read(authProvider.notifier).requestOtp(mobile);
      if (mounted) context.push("/otp", extra: "/login");
    } catch (e) {
      final s = e.toString();
      setState(() {
        _notRegistered =
            s.contains("MOBILE_NOT_FOUND") || s.contains("USER_NOT_FOUND");
        _error =
            _notRegistered ? "This number isn't registered yet" : _friendly(e);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains("NETWORK") || s.contains("TIMEOUT")) {
      return "No internet connection. Please try again.";
    }
    return "Something went wrong. Please try again.";
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return CtDoubleBackExit(
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Ct.pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const _Logo(),
                const SizedBox(height: 28),
                Text("Welcome back", style: text.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  "Log in with your mobile number.",
                  style: text.bodyMedium?.copyWith(color: Ct.faded),
                ),
                Text(
                  "ජංගම දුරකථන අංකයෙන් පිවිසෙන්න",
                  style: text.bodyMedium?.copyWith(color: Ct.faded),
                ),
                const SizedBox(height: 28),
                PhoneInputField(
                  controller: _mobile,
                  label: "Mobile number",
                  onChanged: (_) {
                    if (_error != null || _notRegistered) {
                      setState(() {
                        _error = null;
                        _notRegistered = false;
                      });
                    }
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Ct.claySoft,
                      borderRadius: BorderRadius.circular(Ct.radiusSm),
                      border: Border.all(color: Ct.clay.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Ct.clay, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: text.bodyMedium?.copyWith(
                              color: Ct.clay,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_notRegistered) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => context.go("/register"),
                    icon: const Icon(Icons.person_add_alt_1, size: 20),
                    label: const Text("Create an account"),
                  ),
                ],
                const SizedBox(height: 24),
                CtButton(
                  label: "Send code",
                  icon: Icons.arrow_forward,
                  loading: _loading,
                  onPressed: _send,
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => context.go("/register"),
                    child: Text.rich(
                      TextSpan(
                        text: "New to Cinnamon Trace? ",
                        style: const TextStyle(color: Ct.faded),
                        children: const [
                          TextSpan(
                            text: "Create account",
                            style: TextStyle(
                              color: Ct.cinnamon,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Ct.cinnamon,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.spa_outlined, color: Ct.cream, size: 30),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Cinnamon Trace",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              "කුරුඳු සලකුණ",
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Ct.faded),
            ),
          ],
        ),
      ],
    );
  }
}
