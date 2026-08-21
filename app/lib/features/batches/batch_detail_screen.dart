import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../app/theme.dart";
import "../../core/widgets/ct_widgets.dart";
import "../harvest/harvest_done_screen.dart";

/// Batch detail with the upward chain-of-custody timeline.
class BatchDetailScreen extends ConsumerWidget {
  const BatchDetailScreen({super.key, required this.batchId});

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
        title: Text("Batch", style: text.titleLarge),
      ),
      body: SafeArea(
        child: batch.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: Ct.cinnamon)),
          error: (_, __) => Center(
            child: Text("Could not load batch", style: text.bodyMedium),
          ),
          data: (b) {
            final chain = (b["chain"] as List? ?? const [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            final origin = b["origin"] as Map?;
            return ListView(
              padding: const EdgeInsets.all(Ct.pad),
              children: [
                // Header card
                CtCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b["batch_no"].toString(),
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
                          StatusChip(
                            label: b["status"].toString(),
                            color: Ct.leaf,
                          ),
                          StatusChip(
                            label: "${b["weight_kg"]} kg",
                            color: Ct.quill,
                          ),
                          if (b["harvest_type"] != null)
                            StatusChip(
                              label: b["harvest_type"] == "T" ? "Trees" : "Quills",
                              color: Ct.cinnamon,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Origin
                if (origin != null) ...[
                  Text("Origin", style: text.titleLarge),
                  const SizedBox(height: 8),
                  CtCard(
                    color: Ct.leafSoft,
                    child: Row(
                      children: [
                        const Icon(Icons.park, color: Ct.leaf, size: 28),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                origin["farm_name"]?.toString() ?? "Farm",
                                style: text.titleMedium,
                              ),
                              Text(
                                "District ${origin["area_code"] ?? ""}",
                                style: text.bodyMedium
                                    ?.copyWith(color: Ct.faded),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                // Chain timeline
                Text("Chain of Custody", style: text.titleLarge),
                const SizedBox(height: 8),
                if (chain.isEmpty)
                  CtCard(
                    child: Text("No events yet", style: text.bodyMedium),
                  )
                else
                  _Timeline(events: chain),
                const SizedBox(height: 24),
                CtButton(
                  label: "Sell / Hand over",
                  icon: Icons.swap_horiz,
                  onPressed: () => context.go("/transfer/$batchId"),
                ),
                const SizedBox(height: 12),
                CtButton(
                  label: "Show QR",
                  icon: Icons.qr_code,
                  secondary: true,
                  onPressed: () => context.go("/qr/show/$batchId"),
                ),
                const SizedBox(height: 30),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.events});

  final List<Map<String, dynamic>> events;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return CtCard(
      padding: const EdgeInsets.symmetric(horizontal: Ct.pad, vertical: 12),
      child: Column(
        children: [
          for (var i = 0; i < events.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _color(events[i]["event_type"].toString()),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _icon(events[i]["event_type"].toString()),
                        size: 18,
                        color: Ct.paper,
                      ),
                    ),
                    if (i < events.length - 1)
                      Container(
                        width: 2,
                        height: 34,
                        color: Ct.line,
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          events[i]["summary"]?.toString() ??
                              events[i]["event_type"].toString(),
                          style: text.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${events[i]["actor_name"] ?? ""} · ${_roleLabel(events[i]["actor_role"].toString())}",
                          style: text.bodyMedium?.copyWith(color: Ct.faded),
                        ),
                        Text(
                          _fmtDate(events[i]["at"]?.toString()),
                          style: text.labelMedium,
                        ),
                        if (events[i]["anchored"] == true) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.verified,
                                  size: 14, color: Ct.leaf),
                              const SizedBox(width: 4),
                              Text(
                                "On blockchain",
                                style: text.labelMedium
                                    ?.copyWith(color: Ct.leaf),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _color(String type) => switch (type) {
        "CREATED" => Ct.leaf,
        "TRANSFERRED" => Ct.quill,
        "PROCESSED" => Ct.cinnamon,
        "EXPORTED" => Ct.bark,
        _ => Ct.faded,
      };

  IconData _icon(String type) => switch (type) {
        "CREATED" => Icons.spa,
        "TRANSFERRED" => Icons.swap_horiz,
        "PROCESSED" => Icons.precision_manufacturing,
        "EXPORTED" => Icons.flight_takeoff,
        _ => Icons.circle,
      };

  String _roleLabel(String role) => switch (role) {
        "FARMER" => "Farmer",
        "PROCESSOR_L1" => "Processor L1",
        "COLLECTOR" => "Collector",
        "PROCESSOR_L2" => "Processor L2",
        "EXPORTER" => "Exporter",
        _ => role,
      };

  String _fmtDate(String? iso) {
    if (iso == null) return "";
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return "${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, "0")}:${d.minute.toString().padLeft(2, "0")}";
  }
}
