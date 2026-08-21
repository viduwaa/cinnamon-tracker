import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../app/theme.dart";
import "../../core/auth/auth_state.dart";
import "../../core/widgets/ct_widgets.dart";
import "../inbox/inbox_screen.dart";

/// Farmer's farms, fetched from the backend.
final farmsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get("/farms");
  return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

/// Farmer's batches, fetched from the backend.
final batchesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get("/batches", query: {"limit": 50});
  final list = (data as Map)["data"] as List? ?? const [];
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farms = ref.watch(farmsProvider);
    final batches = ref.watch(batchesProvider);
    final text = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(farmsProvider);
        ref.invalidate(batchesProvider);
        ref.invalidate(inboxProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(Ct.pad),
        children: [
          const _InboxBanner(),
          // Farms section
          Row(
            children: [
              Text("My Farms", style: text.titleLarge),
              const Spacer(),
              TextButton.icon(
                onPressed: () => context.go("/farm/new"),
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Add"),
              ),
            ],
          ),
          const SizedBox(height: 8),
          farms.when(
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(message: "Could not load farms", retry: () => ref.invalidate(farmsProvider)),
            data: (list) => list.isEmpty
                ? _EmptyFarms(onAdd: () => context.go("/farm/new"))
                : Column(
                    children: [
                      for (final f in list) _FarmCard(farm: f),
                    ],
                  ),
          ),
          const SizedBox(height: 24),
          // Batches section
          Text("Active Batches", style: text.titleLarge),
          const SizedBox(height: 8),
          batches.when(
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(message: "Could not load batches", retry: () => ref.invalidate(batchesProvider)),
            data: (list) => list.isEmpty
                ? _EmptyBatches(onAdd: () => context.go("/harvest"))
                : Column(
                    children: [
                      for (final b in list)
                        _BatchCard(
                          batch: b,
                          onTap: () => context.go("/batch/${b["id"]}"),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 90), // room for FAB
        ],
      ),
    );
  }
}

class _FarmCard extends StatelessWidget {
  const _FarmCard({required this.farm});

  final Map<String, dynamic> farm;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CtCard(
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Ct.leafSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.yard_outlined, color: Ct.leaf, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(farm["name"].toString(), style: text.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    "${farm["size_value"]} ${_unit(farm["size_unit"].toString())} · ${farm["area_code"]}",
                    style: text.bodyMedium?.copyWith(color: Ct.faded),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Ct.quillSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                farm["farmer_code"].toString(),
                style: text.titleMedium?.copyWith(color: Ct.cinnamon),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _unit(String u) => switch (u) {
        "PERCH" => "perches",
        "HECTARE" => "ha",
        _ => "acres",
      };
}

class _BatchCard extends StatelessWidget {
  const _BatchCard({required this.batch, required this.onTap});

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  batch["harvest_type"] == "T"
                      ? Icons.park_outlined
                      : Icons.grain_outlined,
                  color: Ct.cinnamon,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    batch["batch_no"].toString(),
                    style: text.titleMedium?.copyWith(
                      fontFamily: Ct.display,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                _statusChip(status),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              "${batch["weight_kg"]} kg · ${fmtDate(batch["harvest_date"]?.toString())}",
              style: text.bodyMedium?.copyWith(color: Ct.faded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) => switch (status) {
        "HARVESTED" => const StatusChip(label: "Harvested", color: Ct.leaf),
        "IN_TRANSIT" => const StatusChip(label: "In transit", color: Ct.quill),
        "RECEIVED" => const StatusChip(label: "Received", color: Ct.cinnamon),
        "PROCESSED" => const StatusChip(label: "Processed", color: Ct.cinnamon),
        "EXPORTED" => const StatusChip(label: "Exported", color: Ct.bark),
        _ => StatusChip(label: status, color: Ct.faded),
      };
}

class _EmptyFarms extends StatelessWidget {
  const _EmptyFarms({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return CtCard(
      color: Ct.leafSoft,
      child: Column(
        children: [
          const Icon(Icons.yard_outlined, size: 44, color: Ct.leaf),
          const SizedBox(height: 10),
          Text(
            "Add your first farm",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            "You need a farm before you can record a harvest.",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Ct.faded),
          ),
          const SizedBox(height: 16),
          CtButton(label: "Add Farm", icon: Icons.add, onPressed: onAdd),
        ],
      ),
    );
  }
}

class _EmptyBatches extends StatelessWidget {
  const _EmptyBatches({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return CtCard(
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined, size: 40, color: Ct.faded),
          const SizedBox(height: 10),
          Text(
            "No batches yet",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            "Tap “New Batch” after you harvest.",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Ct.faded),
          ),
          const SizedBox(height: 16),
          CtButton(label: "New Batch", icon: Icons.add, onPressed: onAdd),
        ],
      ),
    );
  }
}

/// Banner shown at the top of Home when there are incoming batches.
class _InboxBanner extends ConsumerWidget {
  const _InboxBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(inboxProvider);
    final text = Theme.of(context).textTheme;
    final count = inbox.maybeWhen(data: (l) => l.length, orElse: () => 0);
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: CtCard(
        color: Ct.quillSoft,
        onTap: () => context.go("/inbox"),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.move_to_inbox, color: Ct.cinnamon, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "$count batch${count == 1 ? "" : "es"} waiting for you",
                style: text.titleMedium?.copyWith(color: Ct.cinnamon),
              ),
            ),
            const Icon(Icons.chevron_right, color: Ct.cinnamon),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const CtCard(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(color: Ct.cinnamon),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    return CtCard(
      color: Ct.claySoft,
      child: Column(
        children: [
          const Icon(Icons.cloud_off, size: 36, color: Ct.clay),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          CtButton(label: "Retry", secondary: true, onPressed: retry),
        ],
      ),
    );
  }
}
