import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../app/theme.dart";
import "../../core/auth/auth_state.dart";
import "../../core/widgets/ct_widgets.dart";

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
  final _selected = <String>{"FARMER"};
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_name.text.trim().length < 2) {
      setState(() => _error = "Please enter your name");
      return;
    }
    final mobile = _normalizeMobile(_mobile.text);
    if (mobile == null) {
      setState(() => _error = "Please enter a valid mobile number");
      return;
    }
    if (_selected.isEmpty) {
      setState(() => _error = "Select at least one role");
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider.notifier);
      try {
        await auth.register(
          name: _name.text.trim(),
          mobile: mobile,
          roles: _selected.toList(),
          email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        );
      } catch (e) {
        // Already registered → this is a login. Just send the OTP.
        if (!e.toString().contains("MOBILE_TAKEN")) rethrow;
      }
      await auth.requestOtp(mobile);
      if (mounted) context.go("/otp");
    } catch (e) {
      setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _normalizeMobile(String raw) {
    var digits = raw.replaceAll(RegExp(r"[^0-9]"), "");
    if (digits.startsWith("0")) digits = "94${digits.substring(1)}";
    if (digits.length < 9) return null;
    return "+$digits";
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains("MOBILE_TAKEN")) return "This mobile is already registered";
    if (s.contains("NETWORK") || s.contains("TIMEOUT")) {
      return "No internet connection. Please try again.";
    }
    return "Something went wrong. Please try again.";
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Ct.pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              _Logo(),
              const SizedBox(height: 28),
              Text("Create your account", style: text.headlineMedium),
              const SizedBox(height: 6),
              Text(
                "Track your cinnamon from farm to export.",
                style: text.bodyMedium?.copyWith(color: Ct.faded),
              ),
              const SizedBox(height: 28),
              CtField(
                label: "Your name",
                controller: _name,
                hint: "Sunil Perera",
                prefix: const Icon(Icons.person_outline, color: Ct.faded),
              ),
              const SizedBox(height: 18),
              CtField(
                label: "Mobile number",
                controller: _mobile,
                hint: "077 123 4567",
                keyboardType: TextInputType.phone,
                prefix: const Icon(Icons.phone_outlined, color: Ct.faded),
              ),
              const SizedBox(height: 18),
              CtField(
                label: "Email (optional)",
                controller: _email,
                hint: "you@example.com",
                keyboardType: TextInputType.emailAddress,
                prefix: const Icon(Icons.mail_outline, color: Ct.faded),
              ),
              const SizedBox(height: 26),
              Text("I am a…  (select all that apply)", style: text.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final r in _roles) _RoleChip(
                    code: r.$1,
                    en: r.$2,
                    si: r.$3,
                    icon: r.$4,
                    selected: _selected.contains(r.$1),
                    onTap: () => setState(() {
                      if (_selected.contains(r.$1)) {
                        _selected.remove(r.$1);
                      } else {
                        _selected.add(r.$1);
                      }
                    }),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Ct.claySoft,
                    borderRadius: BorderRadius.circular(Ct.radiusSm),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Ct.clay, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: text.bodyMedium?.copyWith(color: Ct.clay),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              CtButton(
                label: "Continue",
                icon: Icons.arrow_forward,
                loading: _loading,
                onPressed: _continue,
              ),
              const SizedBox(height: 16),
            ],
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
