import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../app/theme.dart";
import "../../core/auth/auth_state.dart";
import "../../core/widgets/ct_widgets.dart";
import "../home/home_screen.dart";

/// Incoming transfers for the current user.
final inboxProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get("/inbox");
  return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(inboxProvider);
    final text = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(inboxProvider),
      child: inbox.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Ct.cinnamon)),
        error: (_, __) => Center(
          child: CtButton(
            label: "Retry",
            secondary: true,
            onPressed: () => ref.invalidate(inboxProvider),
          ),
        ),
        data: (list) => list.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(Ct.pad),
                children: [
                  const SizedBox(height: 60),
                  CtCard(
                    child: Column(
                      children: [
                        const Icon(Icons.move_to_inbox_outlined,
                            size: 44, color: Ct.faded),
                        const SizedBox(height: 10),
                        Text("Nothing incoming", style: text.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          "Batches sent to you will appear here.",
                          textAlign: TextAlign.center,
                          style:
                              text.bodyMedium?.copyWith(color: Ct.faded),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(Ct.pad),
                itemCount: list.length,
                itemBuilder: (context, i) => _InboxCard(item: list[i]),
              ),
      ),
    );
  }
}

class _InboxCard extends ConsumerWidget {
  const _InboxCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CtCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item["batch_no"].toString(),
                    style: text.titleMedium
                        ?.copyWith(fontFamily: Ct.display),
                  ),
                ),
                StatusChip(
                  label: item["transfer_kind"] == "SALE" ? "For sale" : "Handover",
                  color: item["transfer_kind"] == "SALE" ? Ct.quill : Ct.leaf,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "From ${item["from_name"]} · ${item["from_role"]}",
              style: text.bodyMedium?.copyWith(color: Ct.faded),
            ),
            Text(
              "${item["weight_kg"]} kg",
              style: text.bodyMedium?.copyWith(color: Ct.faded),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: CtButton(
                    secondary: true,
                    label: "View",
                    onPressed: () =>
                        context.go("/batch/${item["batch_id"]}"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CtButton(
                    label: "Accept",
                    icon: Icons.check,
                    onPressed: () async {
                      await _accept(context, ref, item["batch_id"].toString());
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _accept(
      BuildContext context, WidgetRef ref, String batchId) async {
    try {
      await ref.read(apiClientProvider).post("/inbox/$batchId/accept");
      ref.invalidate(inboxProvider);
      ref.invalidate(batchesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Batch received"),
            backgroundColor: Ct.leaf,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not accept — try again")),
        );
      }
    }
  }
}
