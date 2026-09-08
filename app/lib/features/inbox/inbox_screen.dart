import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../app/theme.dart";
import "../../core/auth/auth_state.dart";
import "../../core/data/repositories.dart";
import "../../core/widgets/ct_widgets.dart";

/// Incoming transfers for the current user.
final inboxProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get("/inbox");
  return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  @override
  void initState() {
    super.initState();
    // Always re-fetch on open: transfers sent to this account land server-side
    // and nothing else pushes them into this cached provider.
    Future.microtask(() => ref.invalidate(inboxProvider));
  }

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(inboxProvider);
    final text = Theme.of(context).textTheme;
    final auth = ref.watch(authProvider);
    final user = auth is SignedIn ? auth.user : null;
    final activeRole = ref.watch(activeRoleProvider);
    final roles = user?.roles ?? const <String>[];
    // Multi-role accounts only see what was addressed to the acting role.
    final effectiveRole =
        roles.contains(activeRole) ? activeRole : (roles.firstOrNull ?? "");
    final scopeByRole = roles.length > 1;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(inboxProvider),
      child: inbox.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Ct.cinnamon)),
        error: (err, stack) => Center(
          child: CtButton(
            label: "Retry",
            secondary: true,
            onPressed: () => ref.invalidate(inboxProvider),
          ),
        ),
        data: (all) {
          final list = scopeByRole
              ? all
                  .where((e) =>
                      (e["to_role"]?.toString() ?? "") == effectiveRole)
                  .toList()
              : all;
          final otherRoleItems = scopeByRole
              ? all
                  .where((e) =>
                      (e["to_role"]?.toString() ?? "") != effectiveRole)
                  .toList()
              : const <Map<String, dynamic>>[];
          return ListView(
            padding: const EdgeInsets.all(Ct.pad),
            children: [
              if (scopeByRole) ...[
                _ReceivingAs(role: effectiveRole),
                const SizedBox(height: 14),
              ],
              if (otherRoleItems.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: CtCard(
                    color: Ct.quillSoft,
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: Ct.cinnamon, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "${otherRoleItems.length} batch${otherRoleItems.length == 1 ? "" : "es"} incoming for ${_roleLabel(otherRoleItems.first["to_role"]?.toString() ?? "")}",
                            style: text.bodyMedium?.copyWith(
                              color: Ct.cinnamon,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            final target =
                                otherRoleItems.first["to_role"]?.toString();
                            if (target != null) {
                              ref.read(activeRoleProvider.notifier).state =
                                  target;
                            }
                          },
                          child: const Text("Switch"),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 46),
                  child: CtCard(
                    child: Column(
                      children: [
                        const Icon(Icons.move_to_inbox_outlined,
                            size: 44, color: Ct.faded),
                        const SizedBox(height: 10),
                        Text("Nothing incoming", style: text.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          scopeByRole
                              ? "Batches addressed to ${_roleLabel(effectiveRole)} will appear here."
                              : "Batches sent to you will appear here.",
                          textAlign: TextAlign.center,
                          style:
                              text.bodyMedium?.copyWith(color: Ct.faded),
                        ),
                      ],
                    ),
                  ),
                )
              else
                for (final item in list)
                  _InboxCard(key: ValueKey(item["batch_id"]), item: item),
            ],
          );
        },
      ),
    );
  }
}

/// Small strip naming the role currently receiving — mirrors the Home role
/// switch so a multi-role user always knows which queue they are looking at.
class _ReceivingAs extends StatelessWidget {
  const _ReceivingAs({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Ct.quillSoft,
        borderRadius: BorderRadius.circular(Ct.radiusSm),
      ),
      child: Row(
        children: [
          const Icon(Icons.inbox_outlined, color: Ct.cinnamon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Receiving as ${_roleLabel(role)}",
              style: text.titleMedium?.copyWith(color: Ct.cinnamon),
            ),
          ),
        ],
      ),
    );
  }
}

/// Accepts an incoming transfer and pulls server truth into drift so every
/// watching surface (Home counts, held lists, batch detail) reflects it at
/// once. Shared by the Inbox screen and the Home incoming queue.
Future<void> acceptIncoming(
  BuildContext context,
  WidgetRef ref,
  String batchId,
) async {
  try {
    final res = await ref.read(apiClientProvider).post("/inbox/$batchId/accept");
    final auth = ref.read(authProvider);
    final myId = auth is SignedIn ? auth.user.id : null;
    final activeRole = ref.read(activeRoleProvider);
    final holderRole = (res is Map && res["current_holder_role"] != null)
        ? res["current_holder_role"].toString()
        : activeRole;
    if (myId != null) {
      await ref.read(batchesRepoProvider).updateBatchLocalAccept(
            batchId: batchId,
            holderId: myId,
            holderRole: holderRole,
          );
    }
    try {
      await ref.read(batchesRepoProvider).pullBatches();
    } catch (_) {}
    ref.invalidate(inboxProvider);
    ref.invalidate(batchesProvider);
    ref.invalidate(batchByIdProvider(batchId));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Batch received into your custody"),
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

class _InboxCard extends ConsumerStatefulWidget {
  const _InboxCard({super.key, required this.item});

  final Map<String, dynamic> item;

  @override
  ConsumerState<_InboxCard> createState() => _InboxCardState();
}

class _InboxCardState extends ConsumerState<_InboxCard> {
  bool _accepting = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final item = widget.item;
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
              "From ${item["from_name"]} · ${_roleLabel(item["from_role"].toString())}",
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
                    enabled: !_accepting,
                    onPressed: () =>
                        context.push("/batch/${item["batch_id"]}"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CtButton(
                    label: "Accept",
                    icon: Icons.check,
                    loading: _accepting,
                    onPressed: () async {
                      await _accept(item["batch_id"].toString());
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

  Future<void> _accept(String batchId) async {
    setState(() => _accepting = true);
    await acceptIncoming(context, ref, batchId);
    if (mounted) setState(() => _accepting = false);
  }
}

String _roleLabel(String role) => ctRoleLabel(role);
