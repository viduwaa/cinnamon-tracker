import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../app/theme.dart";
import "../../core/auth/biometric_service.dart";
import "../../core/widgets/ct_widgets.dart";

/// Shows the post-login opt-in sheet inviting the user to enable fingerprint authentication.
Future<bool?> showBiometricPromptSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<bool>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const BiometricPromptSheet(),
  );
}

class BiometricPromptSheet extends ConsumerStatefulWidget {
  const BiometricPromptSheet({super.key});

  @override
  ConsumerState<BiometricPromptSheet> createState() => _BiometricPromptSheetState();
}

class _BiometricPromptSheetState extends ConsumerState<BiometricPromptSheet> {
  bool _loading = false;
  String? _error;

  Future<void> _enable() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final success = await ref.read(biometricProvider.notifier).enableBiometrics();
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _error = "Biometric authentication was cancelled or not recognized. Try again or skip for now.";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Could not activate biometrics: ${e.toString()}";
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      decoration: const BoxDecoration(
        color: Ct.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(Ct.pad, 20, Ct.pad, Ct.pad + 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Ct.faded.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Ct.cinnamon.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Ct.cinnamon.withValues(alpha: 0.25),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.fingerprint_rounded,
                  color: Ct.cinnamon,
                  size: 44,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Enable Fingerprint Login?",
              textAlign: TextAlign.center,
              style: text.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontFamily: Ct.display,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "ඇඟිලි සලකුණු පිවිසුම සක්‍රිය කරන්නද?",
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(
                color: Ct.faded,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Ct.cream,
                borderRadius: BorderRadius.circular(Ct.radiusSm),
                border: Border.all(color: Ct.cinnamon.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.speed_outlined, size: 20, color: Ct.cinnamon),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Instant & Secure Access",
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Ct.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Unlock Cinnamon Trace securely without waiting for an SMS code every time you open the app.",
                    style: text.bodyMedium?.copyWith(color: Ct.ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "මීළඟ වතාවේ යෙදුම විවෘත කිරීමේදී ඔබගේ ඇඟිලි සලකුණ භාවිතයෙන් පහසුවෙන් සහ ආරක්‍ෂිතව පිවිසෙන්න.",
                    style: text.bodySmall?.copyWith(color: Ct.faded),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Ct.claySoft,
                  borderRadius: BorderRadius.circular(Ct.radiusSm),
                  border: Border.all(color: Ct.clay.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Ct.clay, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: text.bodySmall?.copyWith(color: Ct.clay),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            CtButton(
              label: "Enable Fingerprint",
              icon: Icons.fingerprint,
              loading: _loading,
              onPressed: _enable,
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: _loading ? null : () => Navigator.of(context).pop(false),
                child: Text(
                  "Maybe Later  ·  පසුව",
                  style: text.labelLarge?.copyWith(
                    color: Ct.faded,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
