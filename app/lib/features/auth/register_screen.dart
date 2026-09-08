import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../app/theme.dart";
import "../../core/auth/auth_state.dart";
import "../../core/widgets/ct_widgets.dart";
import "../../core/widgets/phone_input_field.dart";

const _roles = [
  ("FARMER", "Farmer", "ගොවියා", Icons.grass_outlined),
  ("PROCESSOR_L1", "Processor L1", "සකසන්නා 1", Icons.precision_manufacturing_outlined),
  ("COLLECTOR", "Collector", "එකතු කරන්නා", Icons.local_shipping_outlined),
  ("PROCESSOR_L2", "Processor L2", "සකසන්නා 2", Icons.factory_outlined),
  ("EXPORTER", "Exporter", "නිර්යාතක", Icons.flight_takeoff_outlined),
];

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _selectedRoles = <String>{"FARMER"};
  
  bool _isSignInMode = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final mobile = normalizePhoneNumber(_mobile.text);
    if (mobile.length < 8) {
      setState(() => _error = "Please enter a valid mobile number");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = ref.read(authProvider.notifier);

    if (_isSignInMode) {
      // -------------------------------------------------------------
      // SIGN IN FLOW
      // -------------------------------------------------------------
      try {
        await auth.requestOtp(mobile);
        if (mounted) context.push("/otp", extra: "/register");
      } catch (e) {
        setState(() => _error = _friendly(e));
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    } else {
      // -------------------------------------------------------------
      // REGISTER FLOW (STRICT UNIQUE NUMBER CHECK)
      // -------------------------------------------------------------
      if (_name.text.trim().length < 2) {
        setState(() {
          _error = "Please enter your full name";
          _loading = false;
        });
        return;
      }
      if (_selectedRoles.isEmpty) {
        setState(() {
          _error = "Select at least one role to continue";
          _loading = false;
        });
        return;
      }

      try {
        await auth.register(
          name: _name.text.trim(),
          mobile: mobile,
          roles: _selectedRoles.toList(),
          email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        );
        await auth.requestOtp(mobile);
        if (mounted) context.push("/otp", extra: "/register");
      } catch (e) {
        setState(() => _error = _friendly(e));
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains("MOBILE_TAKEN")) {
      return "This mobile number is already registered. Please sign in instead.";
    }
    if (s.contains("NETWORK") || s.contains("TIMEOUT")) {
      return "No internet connection. Please check your network and try again.";
    }
    return "Something went wrong. Please check your details and try again.";
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
                _Logo(),
                const SizedBox(height: 24),
                // Mode Switcher (Sign In vs Create Account)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Ct.cream,
                    borderRadius: BorderRadius.circular(Ct.radiusSm),
                    border: Border.all(color: Ct.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _AuthModeTab(
                          label: "Sign In",
                          selected: _isSignInMode,
                          onTap: () => setState(() {
                            _isSignInMode = true;
                            _error = null;
                          }),
                        ),
                      ),
                      Expanded(
                        child: _AuthModeTab(
                          label: "Create Account",
                          selected: !_isSignInMode,
                          onTap: () => setState(() {
                            _isSignInMode = false;
                            _error = null;
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _isSignInMode ? "Welcome back" : "Create your account",
                  style: text.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  _isSignInMode
                      ? "Enter your mobile number to receive a secure login code."
                      : "Track your cinnamon from farm to export. One account per mobile number.",
                  style: text.bodyMedium?.copyWith(color: Ct.faded),
                ),
                const SizedBox(height: 24),

                // Name Field (Only in Register mode)
                if (!_isSignInMode) ...[
                  CtField(
                    label: "Your full name",
                    controller: _name,
                    hint: "Sunil Perera",
                    prefix: const Icon(Icons.person_outline, color: Ct.faded),
                  ),
                  const SizedBox(height: 18),
                ],

                // Phone Input with Country Code Selector
                PhoneInputField(
                  controller: _mobile,
                  label: "Mobile number",
                  onChanged: (_) {
                    if (_error != null) {
                      setState(() => _error = null);
                    }
                  },
                ),
                const SizedBox(height: 18),

                // Email Field (Only in Register mode)
                if (!_isSignInMode) ...[
                  CtField(
                    label: "Email address (optional)",
                    controller: _email,
                    hint: "you@example.com",
                    keyboardType: TextInputType.emailAddress,
                    prefix: const Icon(Icons.mail_outline, color: Ct.faded),
                  ),
                  const SizedBox(height: 24),
                  Text("Initial Role(s)", style: text.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    "You can add more roles later from your Settings menu.",
                    style: text.labelMedium?.copyWith(color: Ct.faded),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final r in _roles)
                        _RoleChip(
                          code: r.$1,
                          en: r.$2,
                          si: r.$3,
                          icon: r.$4,
                          selected: _selectedRoles.contains(r.$1),
                          onTap: () => setState(() {
                            if (_selectedRoles.contains(r.$1)) {
                              if (_selectedRoles.length > 1) {
                                _selectedRoles.remove(r.$1);
                              }
                            } else {
                              _selectedRoles.add(r.$1);
                            }
                          }),
                        ),
                    ],
                  ),
                ],

                // Error Banner with Switch to Sign In shortcut if MOBILE_TAKEN
                if (_error != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Ct.claySoft,
                      borderRadius: BorderRadius.circular(Ct.radiusSm),
                      border: Border.all(color: Ct.clay.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
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
                        if (_error!.contains("already registered") && !_isSignInMode) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isSignInMode = true;
                                  _error = null;
                                });
                              },
                              icon: const Icon(Icons.login, size: 16),
                              label: const Text("Sign In Instead"),
                              style: TextButton.styleFrom(
                                foregroundColor: Ct.cinnamon,
                                textStyle: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 28),
                CtButton(
                  label: _isSignInMode ? "Send Login Code" : "Create Account",
                  icon: Icons.arrow_forward,
                  loading: _loading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 16),

                // Switcher helper text at bottom
                Center(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignInMode = !_isSignInMode;
                        _error = null;
                      });
                    },
                    child: Text(
                      _isSignInMode
                          ? "Don't have an account? Create one"
                          : "Already have an account? Sign In",
                      style: text.bodyMedium?.copyWith(
                        color: Ct.cinnamon,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthModeTab extends StatelessWidget {
  const _AuthModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Ct.paper : Colors.transparent,
          borderRadius: BorderRadius.circular(Ct.radiusSm - 2),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? Ct.cinnamon : Ct.faded,
                ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
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

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.code,
    required this.en,
    required this.si,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final String en;
  final String si;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Ct.leafSoft : Ct.paper,
          borderRadius: BorderRadius.circular(Ct.radiusSm),
          border: Border.all(
            color: selected ? Ct.leaf : Ct.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: selected ? Ct.leaf : Ct.faded),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  en,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected ? Ct.leaf : Ct.ink,
                      ),
                ),
                Text(
                  si,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: selected ? Ct.leaf : Ct.faded),
                ),
              ],
            ),
            if (selected) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle, size: 18, color: Ct.leaf),
            ],
          ],
        ),
      ),
    );
  }
}
