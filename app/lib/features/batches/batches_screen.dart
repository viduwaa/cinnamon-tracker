import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../app/theme.dart";
import "../../core/widgets/ct_widgets.dart";
import "../home/home_screen.dart";

class BatchesScreen extends ConsumerWidget {
  const BatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batches = ref.watch(batchesProvider);
    final text = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(batchesProvider),
      child: batches.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Ct.cinnamon)),
        error: (_, __) => ListView(
          children: [
            const SizedBox(height: 80),
            Padding(
              padding: const EdgeInsets.all(Ct.pad),
              child: CtCard(
                color: Ct.claySoft,
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off, size: 36, color: Ct.clay),
                    const SizedBox(height: 8),
                    Text("Could not load batches", style: text.bodyMedium),
                    const SizedBox(height: 12),
                    CtButton(
                      label: "Retry",
                      secondary: true,
                      onPressed: () => ref.invalidate(batchesProvider),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        data: (list) => list.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 80),
                  Padding(
                    padding: const EdgeInsets.all(Ct.pad),
                    child: CtCard(
                      child: Column(
                        children: [
                          const Icon(Icons.inventory_2_outlined,
                              size: 44, color: Ct.faded),
                          const SizedBox(height: 10),
                          Text("No batches yet", style: text.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            "Record your first harvest to get started.",
                            textAlign: TextAlign.center,
                            style: text.bodyMedium?.copyWith(color: Ct.faded),
                          ),
                          const SizedBox(height: 16),
                          CtButton(
                            label: "New Batch",
                            icon: Icons.add,
                            onPressed: () => context.go("/harvest"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(Ct.pad),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final b = list[i];
                  return _BatchRow(
                    batch: b,
                    onTap: () => context.go("/batch/${b["id"]}"),
                  );
                },
              ),
      ),
    );
  }
}

class _BatchRow extends StatelessWidget {
  const _BatchRow({required this.batch, required this.onTap});

  final Map<String, dynamic> batch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final status = batch["status"].toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CtCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Ct.quillSoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                batch["harvest_type"] == "T"
                    ? Icons.park_outlined
                    : Icons.grain_outlined,
                color: Ct.cinnamon,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    batch["batch_no"].toString(),
                    style: text.titleMedium?.copyWith(
                      fontFamily: Ct.display,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${batch["weight_kg"]} kg · ${fmtDate(batch["harvest_date"]?.toString())}",
                    style: text.bodyMedium?.copyWith(color: Ct.faded),
                  ),
                ],
              ),
            ),
            _chip(status),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: Ct.faded),
          ],
        ),
      ),
    );
  }

  Widget _chip(String status) => switch (status) {
        "HARVESTED" => const StatusChip(label: "Harvested", color: Ct.leaf),
        "IN_TRANSIT" => const StatusChip(label: "Transit", color: Ct.quill),
        "RECEIVED" => const StatusChip(label: "Received", color: Ct.cinnamon),
        "PROCESSED" => const StatusChip(label: "Processed", color: Ct.cinnamon),
        "EXPORTED" => const StatusChip(label: "Exported", color: Ct.bark),
        _ => StatusChip(label: status, color: Ct.faded),
      };
}
