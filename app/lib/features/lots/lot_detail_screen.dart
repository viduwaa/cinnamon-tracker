import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../app/theme.dart";
import "../../core/api/api_exception.dart";
import "../../core/auth/auth_state.dart";
import "../../core/widgets/ct_widgets.dart";

/// Export lot detail: shipment facts + every merged origin batch with its
/// chain. Mirrors the public verify page's lot view (api-spec §8).
class LotDetailScreen extends ConsumerStatefulWidget {
  const LotDetailScreen({super.key, required this.lotId});

  final String lotId;

  @override
  ConsumerState<LotDetailScreen> createState() => _LotDetailScreenState();
}

class _LotDetailScreenState extends ConsumerState<LotDetailScreen> {
  Map<String, dynamic>? _lot;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get("/lots/${widget.lotId}");
      if (!mounted) return;
      setState(() {
        _lot = Map<String, dynamic>.from(data as Map);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.status == 404 ? "Lot not found" : "Could not load lot";
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "No connection — try again later";
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final lot = _lot;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Ct.ink),
          onPressed: () => ctNavigateBack(context, fallback: "/home"),
        ),
        title: Text("Export lot", style: text.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Ct.ink),
            onPressed: _load,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Ct.cinnamon))
            : _error != null || lot == null
                ? Center(child: Text(_error ?? "Could not load lot", style: text.bodyMedium))
                : ListView(
                    padding: const EdgeInsets.all(Ct.pad),
                    children: [
                      CtCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lot["lot_no"].toString(),
                              style: text.headlineMedium?.copyWith(
                                fontFamily: Ct.display,
                                color: Ct.cinnamon,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                StatusChip(label: lot["status"].toString(), color: Ct.leaf),
                                StatusChip(
                                  label: "${lot["total_weight_kg"]} kg total",
                                  color: Ct.quill,
                                ),
                                if (lot["container_no"]?.toString().isNotEmpty == true)
                                  StatusChip(
                                    label: "Container ${lot["container_no"]}",
                                    color: Ct.bark,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              [
                                if (lot["buyer_name"]?.toString().isNotEmpty == true)
                                  "Buyer: ${lot["buyer_name"]}",
                                if (lot["destination_country"]?.toString().isNotEmpty == true)
                                  "Destination: ${lot["destination_country"]}",
                                if (lot["shipment_date"]?.toString().isNotEmpty == true)
                                  "Ships: ${fmtDate(lot["shipment_date"]?.toString())}",
                              ].join(" · "),
                              style: text.bodyMedium?.copyWith(color: Ct.faded),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text("Origin batches", style: text.titleLarge),
                      const SizedBox(height: 8),
                      for (final rawOrigin in (lot["origins"] as List? ?? const [])) ...[
                        _OriginCard(origin: Map<String, dynamic>.from(rawOrigin as Map)),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 24),
                      CtButton(
                        label: "Show lot QR",
                        icon: Icons.qr_code,
                        secondary: true,
                        onPressed: () => context.push("/qr/show/${lot["lot_id"]}"),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
      ),
    );
  }
}

class _OriginCard extends StatelessWidget {
  const _OriginCard({required this.origin});

  final Map<String, dynamic> origin;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final originInfo = origin["origin"] as Map?;
    final chain = (origin["chain"] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return CtCard(
      color: Ct.leafSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.park, color: Ct.leaf, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      origin["batch_no"]?.toString() ?? "Batch",
                      style: text.titleMedium?.copyWith(fontFamily: Ct.display),
                    ),
                    Text(
                      [
                        if (originInfo?["farm_name"]?.toString().isNotEmpty == true)
                          originInfo?["farm_name"].toString(),
                        if (originInfo?["district"]?.toString().isNotEmpty == true)
                          "District ${originInfo?["district"]}",
                      ].join(" · "),
                      style: text.bodyMedium?.copyWith(color: Ct.faded),
                    ),
                  ],
                ),
              ),
              Text("${origin["weight_kg"]} kg", style: text.titleMedium),
            ],
          ),
          const SizedBox(height: 10),
          for (final e in chain)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 8, color: Ct.cinnamon),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "${e["summary"] ?? e["event_type"]} — ${e["actor_name"]} (${ctRoleLabel(e["actor_role"].toString())})",
                      style: text.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
