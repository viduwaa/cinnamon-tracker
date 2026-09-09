import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:qr_flutter/qr_flutter.dart";
import "package:share_plus/share_plus.dart";
import "../../app/theme.dart";
import "../../core/data/repositories.dart";
import "../../core/widgets/ct_widgets.dart";

class HarvestDoneScreen extends ConsumerWidget {
  const HarvestDoneScreen({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batch = ref.watch(batchByIdProvider(batchId));
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: batch.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: Ct.cinnamon)),
          error: (err, stack) => Center(
            child: CtButton(
              label: "Back to Home",
              onPressed: () => context.go("/home"),
            ),
          ),
          data: (b) {
            final batchNo = b["batch_no"].toString();
            const verifyBase = String.fromEnvironment(
              "VERIFY_BASE_URL",
              defaultValue: "https://api-cinnamon.viduwa.dev/verify",
            );
            final verifyUrl = "$verifyBase/$batchNo";
            return SingleChildScrollView(
              padding: const EdgeInsets.all(Ct.pad),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(
                      color: Ct.leaf,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Ct.paper, size: 48),
                  ),
                  const SizedBox(height: 18),
                  Text("Saved!", style: text.displayLarge),
                  const SizedBox(height: 6),
                  Text(
                    "Your harvest is recorded.",
                    style: text.bodyMedium?.copyWith(color: Ct.faded),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Ct.quillSoft,
                      borderRadius: BorderRadius.circular(Ct.radius),
                    ),
                    child: Text(
                      batchNo,
                      textAlign: TextAlign.center,
                      style: text.headlineMedium?.copyWith(
                        fontFamily: Ct.display,
                        color: Ct.cinnamon,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Ct.paper,
                      borderRadius: BorderRadius.circular(Ct.radius),
                      border: Border.all(color: Ct.line),
                    ),
                    child: QrImageView(
                      data: verifyUrl,
                      version: QrVersions.auto,
                      size: 220,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Ct.bark,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Ct.bark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Scan to verify origin",
                    style: text.labelMedium,
                  ),
                  const SizedBox(height: 24),
                  CtButton(
                    label: "Share on WhatsApp",
                    icon: Icons.share,
                    onPressed: () => Share.share("$batchNo\n$verifyUrl"),
                  ),
                  const SizedBox(height: 12),
                  CtButton(
                    label: "Sell / Hand over",
                    secondary: true,
                    icon: Icons.swap_horiz,
                    onPressed: () => context.push("/transfer/$batchId"),
                  ),
                  const SizedBox(height: 12),
                  CtButton(
                    label: "Done",
                    secondary: true,
                    onPressed: () => context.go("/home"),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
