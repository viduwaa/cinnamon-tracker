import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:mobile_scanner/mobile_scanner.dart";
import "package:qr_flutter/qr_flutter.dart";
import "package:share_plus/share_plus.dart";
import "package:url_launcher/url_launcher.dart";
import "../../app/theme.dart";
import "../../core/auth/auth_state.dart";
import "../../core/data/repositories.dart";
import "../../core/widgets/ct_widgets.dart";
import "../inbox/inbox_screen.dart";

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
          "Scan a batch to collect it, or share your QR so anyone can verify its origin.",
          style: text.bodyMedium?.copyWith(color: Ct.faded),
        ),
        const SizedBox(height: 20),
        CtCard(
          color: Ct.quillSoft,
          onTap: () => context.push("/qr/scan"),
          child: Column(
            children: [
              const Icon(Icons.qr_code_scanner, size: 44, color: Ct.cinnamon),
              const SizedBox(height: 10),
              Text("Scan a batch QR", style: text.titleMedium),
              const SizedBox(height: 4),
              Text(
                "Point the camera at any batch code — incoming transfers can be collected straight from the scan.",
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
      error: (err, stack) => Text("Could not load", style: text.bodyMedium),
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
                      onTap: () => context.push("/qr/show/${b["id"]}"),
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
          onPressed: () => ctNavigateBack(context, fallback: "/qr"),
        ),
        title: Text("Batch QR", style: text.titleLarge),
      ),
      body: SafeArea(
        child: batch.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: Ct.cinnamon)),
          error: (err, stack) =>
              Center(child: Text("Could not load", style: text.bodyMedium)),
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

/// Extracts a batch number from any QR payload we may have issued: a verify
/// URL (…/verify/GM-…), a bare batch number, or a future deep link. Returns
/// null when the payload cannot plausibly be a batch code.
String? _extractBatchNo(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed.contains(RegExp(r"\s"))) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri != null && (uri.scheme == "http" || uri.scheme == "https")) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;
    return segments.last;
  }
  return trimmed;
}

/// Full-screen camera scanner. One flow, routed by batch state:
/// incoming transfer to me → collect sheet · I hold it → batch detail ·
/// otherwise → origin info.
class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key});

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  final _controller = MobileScannerController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null) return;
    final batchNo = _extractBatchNo(code);
    if (batchNo == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final batch =
          await ref.read(batchesRepoProvider).resolveBatchByNo(batchNo);
      if (!mounted) return;
      await _showResult(batch);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            "Could not find batch $batchNo. Check the code and your connection.");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Routing by state (server truth — resolveBatchByNo refreshed it):
  /// IN_TRANSIT to me → collect · held by me → detail · otherwise (someone
  /// else's batch, incl. public-view) → origin info.
  Future<void> _showResult(Map<String, dynamic> batch) {
    final auth = ref.read(authProvider);
    final myId = auth is SignedIn ? auth.user.id : null;
    final holderId = batch["current_holder_id"]?.toString();
    final status = batch["status"]?.toString();
    final isIncoming = myId != null &&
        holderId == myId &&
        status == "IN_TRANSIT";
    final isMine = myId != null && holderId == myId;

    if (isIncoming) {
      return _collectSheet(batch);
    }
    if (isMine && batch["id"] != null) {
      context.push("/batch/${batch["id"]}");
      return Future.value();
    }
    return _infoSheet(batch);
  }

  /// Custody is a server-truth change → explicit confirmation, never
  /// auto-accept on scan.
  Future<void> _collectSheet(Map<String, dynamic> batch) {
    final text = Theme.of(context).textTheme;
    final holderRole = batch["current_holder_role"]?.toString();
    return showModalBottomSheet(
      context: context,
      backgroundColor: Ct.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Ct.radius)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Ct.pad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.move_to_inbox, color: Ct.leaf),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Incoming transfer",
                      style: text.titleLarge?.copyWith(fontFamily: Ct.display),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "${batch["batch_no"]} · ${batch["weight_kg"]} kg\n"
                "Receiving as ${ctRoleLabel((holderRole == null || holderRole.isEmpty) ? "FARMER" : holderRole)}",
                style: text.bodyMedium?.copyWith(color: Ct.faded),
              ),
              const SizedBox(height: 18),
              CtButton(
                label: "Collect batch",
                icon: Icons.download_done,
                onPressed: () async {
                  // Capture router before the async gap; acceptIncoming guards
                  // its own context use internally.
                  final router = GoRouter.of(context);
                  Navigator.pop(sheetContext);
                  await acceptIncoming(context, ref, batch["id"].toString());
                  router.push("/batch/${batch["id"]}");
                },
              ),
              const SizedBox(height: 8),
              CtButton(
                label: "Not now",
                secondary: true,
                onPressed: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Scanned someone else's batch — public origin info + verdict + verify link.
  Future<void> _infoSheet(Map<String, dynamic> batch) {
    final text = Theme.of(context).textTheme;
    const verifyBase = String.fromEnvironment(
      "VERIFY_BASE_URL",
      defaultValue: "https://api-cinnamon.viduwa.dev/verify",
    );
    final verifyUrl = "$verifyBase/${batch["batch_no"]}";
    final origin = batch["origin"] as Map?;
    final verdict = batch["verification"]?.toString();
    final (verdictIcon, verdictColor, verdictLabel) = switch (verdict) {
      "AUTHENTIC" => (Icons.verified, Ct.leaf, "Blockchain-verified"),
      "TAMPERED" => (Icons.gpp_bad, Ct.clay, "Tampering detected"),
      _ => (Icons.schedule, Ct.quill, "Verification pending"),
    };
    final district = (origin?["district"] ?? origin?["area_code"])?.toString();
    final location = origin?["location"] is Map
        ? "Location ${(origin!["location"]["lat"] as num).toStringAsFixed(5)}, "
            "${(origin["location"]["lng"] as num).toStringAsFixed(5)}"
        : (district != null ? "District $district" : null);
    final isPublicView = batch["status"]?.toString() == "PUBLIC";

    return showModalBottomSheet(
      context: context,
      backgroundColor: Ct.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Ct.radius)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Ct.pad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(verdictIcon, color: verdictColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      verdictLabel,
                      style: text.titleLarge
                          ?.copyWith(fontFamily: Ct.display, color: verdictColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                batch["batch_no"].toString(),
                style: text.titleMedium
                    ?.copyWith(fontFamily: Ct.display, color: Ct.cinnamon),
              ),
              const SizedBox(height: 6),
              Text(
                [
                  origin?["farm_name"]?.toString(),
                  location,
                ].where((s) => s != null && s.isNotEmpty).join(" · "),
                style: text.bodyMedium,
              ),
              if (isPublicView) ...[
                const SizedBox(height: 10),
                Text(
                  "This batch belongs to another party — you're seeing its public provenance.",
                  style: text.bodySmall?.copyWith(color: Ct.faded),
                ),
              ],
              const SizedBox(height: 18),
              CtButton(
                label: "Open public verification",
                icon: Icons.open_in_new,
                onPressed: () {
                  Navigator.pop(sheetContext);
                  launchUrl(
                    Uri.parse(verifyUrl),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, color: Ct.ink),
          onPressed: () => ctNavigateBack(context, fallback: "/qr"),
        ),
        title: Text("Scan batch", style: text.titleLarge),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(Ct.pad),
                child: CtCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.no_photography_outlined,
                          size: 40, color: Ct.faded),
                      const SizedBox(height: 10),
                      Text(
                        "Camera unavailable — check that Cinnamon Trace has camera permission in system settings.",
                        textAlign: TextAlign.center,
                        style: text.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(
                  child: CircularProgressIndicator(color: Ct.cream),
                ),
              ),
            ),
          Positioned(
            left: Ct.pad,
            right: Ct.pad,
            bottom: 24 + MediaQuery.of(context).padding.bottom,
            child: Column(
              children: [
                if (_error != null) ...[
                  CtCard(
                    color: Ct.claySoft,
                    child: Text(
                      _error!,
                      style: text.bodyMedium?.copyWith(color: Ct.clay),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ScannerButton(
                      icon: Icons.flash_on,
                      tooltip: "Toggle torch",
                      onTap: () => _controller.toggleTorch(),
                    ),
                    const SizedBox(width: 16),
                    _ScannerButton(
                      icon: Icons.cameraswitch,
                      tooltip: "Switch camera",
                      onTap: () => _controller.switchCamera(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerButton extends StatelessWidget {
  const _ScannerButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(icon, color: Ct.cream, size: 24),
        ),
      ),
    );
  }
}
