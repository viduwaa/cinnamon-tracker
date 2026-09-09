import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../app/theme.dart";
import "../../core/auth/auth_state.dart";
import "../../core/data/repositories.dart";
import "../../core/widgets/ct_widgets.dart";

class BatchesScreen extends ConsumerWidget {
  const BatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batches = ref.watch(batchesProvider);
    final text = Theme.of(context).textTheme;

    final activeRole = ref.watch(activeRoleProvider);
    final auth = ref.watch(authProvider);
    final user = auth is SignedIn ? auth.user : null;
    final roles = user?.roles ?? const ["FARMER"];
    final role =
        roles.contains(activeRole) ? activeRole : (roles.firstOrNull ?? "FARMER");
    final isFarmer = role == "FARMER";
    final myId = user?.id;

    return RefreshIndicator(
      onRefresh: () async {
        try {
          await ref.read(batchesRepoProvider).pullBatches();
        } catch (_) {}
        ref.invalidate(batchesProvider);
      },
      child: batches.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Ct.cinnamon)),
        error: (err, stack) => ListView(
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
        data: (all) {
          // The Batches tab mirrors the acting role — same custody question
          // the Home section asks. Batches held under other roles of yours
          // stay visible in those roles' views.
          final list = all
              .where((b) => ctHeldUnderRole(
                    batch: b,
                    myId: myId,
                    actingRole: role,
                  ))
              .toList();
          final otherRoleCount = all.length - list.length;

          if (list.isEmpty) {
            return ListView(
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
                          isFarmer
                              ? "Record your first harvest to get started."
                              : "Batches you receive and accept from your Inbox will appear here.",
                          textAlign: TextAlign.center,
                          style: text.bodyMedium?.copyWith(color: Ct.faded),
                        ),
                        if (otherRoleCount > 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            "${otherRoleCount == 1 ? "1 batch is" : "$otherRoleCount batches are"} "
                            "held under your other roles — switch role to see ${otherRoleCount == 1 ? "it" : "them"}.",
                            textAlign: TextAlign.center,
                            style: text.bodySmall?.copyWith(color: Ct.faded),
                          ),
                        ],
                        if (isFarmer) ...[
                          const SizedBox(height: 16),
                          CtButton(
                            label: "New Batch",
                            icon: Icons.add,
                            onPressed: () => context.push("/harvest"),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(Ct.pad),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final b = list[i];
              return _BatchRow(
                batch: b,
                actingRole: role,
                onTap: () => context.push("/batch/${b["id"]}"),
              );
            },
          );
        },
      ),
    );
  }
}

class _BatchRow extends ConsumerWidget {
  const _BatchRow({
    required this.batch,
    required this.actingRole,
    required this.onTap,
  });

  final Map<String, dynamic> batch;
  final String actingRole;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final status = batch["status"].toString();
    final auth = ref.watch(authProvider);
    final user = auth is SignedIn ? auth.user : null;
    final myId = user?.id;
    final holderId = batch["current_holder_id"]?.toString();
    final holderRole = batch["current_holder_role"]?.toString();
    final isHeldByMe = myId != null && holderId == myId;
    // Held under the role I am currently acting as (empty holder role is the
    // farmer-era legacy data, same convention as the custody predicate).
    final heldAsActingRole = ctHeldUnderRole(
      batch: batch,
      myId: myId,
      actingRole: actingRole,
    );

    final roleText = (holderRole != null && holderRole.isNotEmpty)
        ? ctRoleLabel(holderRole)
        : "Farmer";
    final actingText = ctRoleLabel(actingRole);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CtCard(
        onTap: onTap,
        color: heldAsActingRole ? Ct.paper : Ct.cream,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: heldAsActingRole ? Ct.quillSoft : Ct.paper,
                borderRadius: BorderRadius.circular(13),
                border: heldAsActingRole
                    ? Border.all(color: Ct.quill.withValues(alpha: 0.3))
                    : null,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          batch["batch_no"].toString(),
                          style: text.titleMedium?.copyWith(
                            fontFamily: Ct.display,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      _chip(status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${batch["weight_kg"]} kg · ${fmtDate(batch["harvest_date"]?.toString())}",
                    style: text.bodyMedium?.copyWith(color: Ct.faded),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: heldAsActingRole
                          ? Ct.leafSoft
                          : Ct.line.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          heldAsActingRole
                              ? Icons.account_circle
                              : Icons.person_outline,
                          size: 14,
                          color: heldAsActingRole ? Ct.leaf : Ct.faded,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          switch ((isHeldByMe, heldAsActingRole)) {
                            // Held under the role I am acting as — the chip
                            // matches the acting role by construction.
                            (true, true) => "Assigned to you as: $actingText",
                            // Held under a different one of my roles — honest
                            // custody plus the action that fixes it.
                            (true, false) =>
                              "Held as $roleText · switch to $roleText to act",
                            // Somebody else's custody (or in transit to them).
                            (false, _) => "With: $roleText",
                          },
                          style: TextStyle(
                            fontFamily: Ct.body,
                            fontSize: 12,
                            fontWeight:
                                heldAsActingRole ? FontWeight.w700 : FontWeight.w600,
                            color: heldAsActingRole ? Ct.leaf : Ct.faded,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Icon(Icons.chevron_right, color: Ct.faded),
            ),
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
