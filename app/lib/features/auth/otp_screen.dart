import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../app/theme.dart";
import "../../core/auth/auth_state.dart";
import "../../core/widgets/ct_widgets.dart";

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _invalidCode = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _mobile {
    final s = ref.read(authProvider);
    return s is OtpSent ? s.mobile : "";
  }

  Future<void> _verify() async {
    if (_controller.text.length != 6) {
      setState(() => _error = "Enter the 6-digit code");
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _invalidCode = false;
    });
    try {
      await ref.read(authProvider.notifier).verifyOtp(_mobile, _controller.text);
      if (mounted) context.go("/home");
    } catch (e) {
      setState(() {
        _invalidCode = e.toString().contains("OTP_INVALID");
        _error = _friendly(e);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains("OTP_INVALID")) return "Wrong code. Please try again.";
    if (s.contains("OTP_LOCKED")) return "Too many attempts. Request a new code.";
    if (s.contains("NETWORK") || s.contains("TIMEOUT")) {
      return "No internet connection. Please try again.";
    }
    return "Something went wrong. Please try again.";
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Where the code was requested: /login or /register (extra set by caller).
    final returnTo = GoRouterState.of(context).extra as String?;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Ct.pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => ctNavigateBack(context, fallback: returnTo ?? "/login"),
                icon: const Icon(Icons.arrow_back, color: Ct.ink),
              ),
              const SizedBox(height: 8),
              Text("Enter your code", style: text.headlineMedium),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: text.bodyMedium?.copyWith(color: Ct.faded),
                  children: [
                    const TextSpan(text: "We sent a 6-digit code to "),
                    TextSpan(
                      text: _mobile,
                      style: text.bodyMedium?.copyWith(
                        color: Ct.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: text.displayLarge?.copyWith(
                  letterSpacing: 14,
                  fontFamily: Ct.display,
                ),
                decoration: const InputDecoration(
                  counterText: "",
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onChanged: (_) => setState(() {
                  _error = null;
                  _invalidCode = false;
                }),
                onSubmitted: (_) => _verify(),
              ),
              const Divider(),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: text.bodyMedium?.copyWith(color: Ct.clay),
                ),
              ],
              // otp/request hides registration status by design, so an
              // unregistered login surfaces here as repeated OTP_INVALID.
              if (returnTo == "/login" && _invalidCode) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go("/register"),
                  child: const Text("Not registered? Create an account"),
                ),
              ],
              const Spacer(),
              CtButton(
                label: "Verify",
                icon: Icons.check_circle_outline,
                loading: _loading,
                onPressed: _verify,
              ),
              const SizedBox(height: 14),
              CtButton(
                label: "Resend code",
                secondary: true,
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await ref.read(authProvider.notifier).requestOtp(_mobile);
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text("Code sent again")),
                      );
                    }
                  } catch (_) {}
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
