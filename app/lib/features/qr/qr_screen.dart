import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:qr_flutter/qr_flutter.dart";
import "package:share_plus/share_plus.dart";
import "../../app/theme.dart";
import "../../core/widgets/ct_widgets.dart";
import "../harvest/harvest_done_screen.dart";
import "../home/home_screen.dart";

/// QR tab: scan entry point + quick display of your own batches.
class QrScreen extends ConsumerWidget {
  const QrScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(Ct.pad),
      children: [
        Text("QR Codes", style: text.headlineMedium),
        const SizedBox(height: 6),
        Text(
          "Share your batch QR so anyone can verify its origin.",
          style: text.bodyMedium?.copyWith(color: Ct.faded),
        ),
        const SizedBox(height: 20),
        CtCard(
          color: Ct.quillSoft,
          child: Column(
            children: [
              const Icon(Icons.qr_code_scanner, size: 44, color: Ct.cinnamon),
              const SizedBox(height: 10),
              Text("Scan a batch QR", style: text.titleMedium),
              const SizedBox(height: 4),
              Text(
                "Camera scanning is available in the Android build.",
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: Ct.faded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text("Your batch QRs", style: text.titleLarge),
        const SizedBox(height: 8),
        _MyQrList(),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _MyQrList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batches = ref.watch(batchesProvider);
    final text = Theme.of(context).textTheme;
    return batches.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Ct.cinnamon)),
      error: (_, __) => Text("Could not load", style: text.bodyMedium),
      data: (list) => list.isEmpty
          ? CtCard(
              child: Text("No batches yet", style: text.bodyMedium),
            )
          : Column(
              children: [
                for (final b in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CtCard(
                      onTap: () => context.go("/qr/show/${b["id"]}"),
                      child: Row(
                        children: [
                          const Icon(Icons.qr_code, color: Ct.cinnamon, size: 30),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              b["batch_no"].toString(),
                              style: text.titleMedium?.copyWith(
                                fontFamily: Ct.display,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Ct.faded),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Full-screen QR display for one batch.
class QrShowScreen extends ConsumerWidget {
  const QrShowScreen({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batch = ref.watch(batchByIdProvider(batchId));
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Ct.ink),
          onPressed: () => context.pop(),
        ),
        title: Text("Batch QR", style: text.titleLarge),
      ),
      body: SafeArea(
        child: batch.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: Ct.cinnamon)),
          error: (_, __) =>
              Center(child: Text("Could not load", style: text.bodyMedium)),
          data: (b) {
            final batchNo = b["batch_no"].toString();
            final verifyUrl = "https://verify.cinnamontrace.example/$batchNo";
            return SingleChildScrollView(
              padding: const EdgeInsets.all(Ct.pad),
              child: Column(
                children: [
                  const SizedBox(height: 8),
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
                      style: text.titleLarge?.copyWith(
                        fontFamily: Ct.display,
                        color: Ct.cinnamon,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Ct.paper,
                      borderRadius: BorderRadius.circular(Ct.radius),
                      border: Border.all(color: Ct.line),
                    ),
                    child: QrImageView(
                      data: verifyUrl,
                      version: QrVersions.auto,
                      size: 260,
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
                  const SizedBox(height: 10),
                  Text("Scan to verify origin", style: text.labelMedium),
                  const SizedBox(height: 24),
                  CtButton(
                    label: "Share on WhatsApp",
                    icon: Icons.share,
                    onPressed: () => Share.share("$batchNo\n$verifyUrl"),
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
