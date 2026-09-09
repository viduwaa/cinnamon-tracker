import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../app/theme.dart";
import "../../core/auth/auth_state.dart";
import "../../core/data/repositories.dart";
import "../../core/sync/sync_worker.dart";
import "../../core/widgets/ct_widgets.dart";
import "../inbox/inbox_screen.dart";

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    Future.microtask(_refreshData);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refreshData(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    try {
      await ref.read(farmsRepoProvider).pullFarms();
    } catch (_) {}
    try {
      await ref.read(batchesRepoProvider).pullBatches();
    } catch (_) {}
    if (mounted) ref.invalidate(inboxProvider);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth is SignedIn ? auth.user : null;
    // The acting role drives the whole dashboard; fall back to the first
    // role on the account when the tab somehow points elsewhere.
    final activeRole = ref.watch(activeRoleProvider);
    final roles = user?.roles ?? const ["FARMER"];
    final role = roles.contains(activeRole) ? activeRole : (roles.firstOrNull ?? "FARMER");
    final farmerView = role == "FARMER";

    final farms = ref.watch(farmsProvider);
    final batches = ref.watch(batchesProvider);

    final myId = user?.id;
    bool heldByMe(Map<String, dynamic> b) =>
        ctHeldUnderRole(batch: b, myId: myId, actingRole: role);

    final batchList =
        batches.asData?.value ?? const <Map<String, dynamic>>[];
    final held = batchList.where(heldByMe).toList();
    final inboxData = ref.watch(inboxProvider).maybeWhen(
          data: (l) => l,
          orElse: () => const <Map<String, dynamic>>[],
        );
    final incoming = roles.length > 1
        ? inboxData.where((e) => (e["to_role"]?.toString() ?? "") == role).length
        : inboxData.length;
    final farmsFirstLoad = farms.isLoading && farms.asData == null;
    final batchesFirstLoad = batches.isLoading && batches.asData == null;

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView(
        padding: const EdgeInsets.all(Ct.pad),
        children: [
          const _SyncBanner(),
          const _InboxBanner(),
          // Swapping the role tab repaints this card first — instant,
          // unmistakable feedback that the workspace changed.
          _RoleSummaryCard(
            role: role,
            farmsCount: farmerView
                ? (farms.asData?.value.length ?? 0)
                : 0,
            heldCount: held.length,
            incomingCount: incoming,
            loading:
                farmerView ? (farmsFirstLoad || batchesFirstLoad) : batchesFirstLoad,
          ),
          const SizedBox(height: 24),
          if (farmerView) ...[
            _SectionHeader(
              title: "My Farms",
              trailing: TextButton.icon(
                onPressed: () => context.push("/farm/new"),
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Add"),
              ),
            ),
            const SizedBox(height: 8),
            farms.when(
              loading: () => const _LoadingCard(),
              error: (e, _) => _ErrorCard(message: "Could not load farms", retry: () => ref.invalidate(farmsProvider)),
              data: (list) => list.isEmpty
                  ? _EmptyFarms(onAdd: () => context.push("/farm/new"))
                  : Column(
                      children: [
                        for (final f in list) _FarmCard(farm: f),
                      ],
                    ),
            ),
            const SizedBox(height: 24),
          ],
          if (farmerView) ...[
            const _SectionHeader(title: "My Batches"),
            const SizedBox(height: 8),
            batches.when(
              loading: () => const _LoadingCard(),
              error: (e, _) => _ErrorCard(message: "Could not load batches", retry: () => ref.invalidate(batchesProvider)),
              data: (list) {
                final heldList = list.where(heldByMe).toList();
                if (heldList.isEmpty) {
                  return _EmptyBatches(onAdd: () => context.push("/harvest"));
                }
                return Column(
                  children: [
                    for (final b in heldList)
                      _BatchCard(
                        batch: b,
                        heldByMe: true,
                        onPass: transferableStatuses
                                .contains(b["status"].toString())
                            ? () => context.push("/transfer/${b["id"]}")
                            : null,
                        onTap: () => context.push("/batch/${b["id"]}"),
                      ),
                  ],
                );
              },
            ),
          ] else ...[
            // Downstream roles live out of their inbox first: the collect
            // queue leads, held stock (with its pass-on action) follows.
            _SectionHeader(
              title: role == "COLLECTOR" ? "To collect" : "Incoming",
            ),
            const SizedBox(height: 8),
            _IncomingQueue(role: role, scopeByRole: roles.length > 1),
            const SizedBox(height: 24),
            _SectionHeader(title: "Batches with you (${ctRoleLabel(role)})"),
            const SizedBox(height: 8),
            batches.when(
              loading: () => const _LoadingCard(),
              error: (e, _) => _ErrorCard(message: "Could not load batches", retry: () => ref.invalidate(batchesProvider)),
              data: (list) {
                final heldList = list.where(heldByMe).toList();
                if (heldList.isEmpty) return const _EmptyHolder();
                return Column(
                  children: [
                    for (final b in heldList)
                      _BatchCard(
                        batch: b,
                        heldByMe: true,
                        onPass: transferableStatuses
                                .contains(b["status"].toString())
                            ? () => context.push("/transfer/${b["id"]}")
                            : null,
                        onTap: () => context.push("/batch/${b["id"]}"),
                      ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 90), // room for FAB
        ],
      ),
    );
  }
}

/// Section title with consistent rhythm across the dashboard.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: Text(title, style: text.titleLarge)),
        ?trailing,
      ],
    );
  }
}

/// Accent-tinted strip that names the acting role and its live numbers —
/// the visible answer to switching role tabs.
class _RoleSummaryCard extends StatelessWidget {
  const _RoleSummaryCard({
    required this.role,
    required this.farmsCount,
    required this.heldCount,
    required this.incomingCount,
    required this.loading,
  });

  final String role;
  final int farmsCount;
  final int heldCount;
  final int incomingCount;
  final bool loading;

  static const _meta = <String, (IconData, Color, String)>{
    "FARMER": (Icons.grass_outlined, Ct.leaf, "ගොවියා"),
    "COLLECTOR":
        (Icons.local_shipping_outlined, Ct.quill, "එකතු කරන්නා"),
    "PROCESSOR_L1":
        (Icons.precision_manufacturing_outlined, Ct.cinnamon, "සකසන්නා 1"),
    "PROCESSOR_L2": (Icons.factory_outlined, Ct.bark, "සකසන්නා 2"),
    "EXPORTER": (Icons.flight_takeoff_outlined, Ct.bark, "නිර්යාතක"),
  };

  String get _headline => switch (role) {
        "FARMER" => "$farmsCount farm${farmsCount == 1 ? "" : "s"} · "
            "$heldCount batch${heldCount == 1 ? "" : "es"} in your hands",
        "COLLECTOR" ||
        "PROCESSOR_L1" ||
        "PROCESSOR_L2" =>
          "$incomingCount incoming · $heldCount held",
        _ => "$heldCount lot${heldCount == 1 ? "" : "s"} ready for export",
      };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (icon, accent, si) = _meta[role] ?? _meta["FARMER"]!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Ct.radius),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            child: Icon(icon, color: Ct.paper, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_roleTitle(role), style: text.titleMedium),
                Text(si,
                    style: text.labelMedium?.copyWith(color: Ct.faded)),
                const SizedBox(height: 4),
                if (loading)
                  Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Ct.cinnamon),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Loading…",
                        style: text.bodyMedium?.copyWith(color: Ct.faded),
                      ),
                    ],
                  )
                else
                  Text(
                    _headline,
                    style: text.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _roleTitle(String role) => switch (role) {
        "FARMER" => "Acting as Farmer",
        "COLLECTOR" => "Acting as Collector",
        "PROCESSOR_L1" => "Acting as Processor L1",
        "PROCESSOR_L2" => "Acting as Processor L2",
        "EXPORTER" => "Acting as Exporter",
        _ => role,
      };
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
              child: (farm["farmer_code"]?.toString().isNotEmpty ?? false)
                  ? Text(
                      farm["farmer_code"].toString(),
                      style: text.titleMedium?.copyWith(color: Ct.cinnamon),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_upload_outlined,
                            size: 14, color: Ct.cinnamon),
                        const SizedBox(width: 4),
                        Text(
                          "Waiting for sync",
                          style: text.labelMedium?.copyWith(color: Ct.cinnamon),
                        ),
                      ],
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
  const _BatchCard({
    required this.batch,
    required this.heldByMe,
    required this.onTap,
    this.onPass,
  });

  final Map<String, dynamic> batch;
  final bool heldByMe;
  final VoidCallback onTap;

  /// Non-null only while the batch is transferable — surfaces the
  /// "pass to any downstream role" action right on the card.
  final VoidCallback? onPass;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CtCard(
        onTap: onTap,
        color: heldByMe ? Ct.paper : Ct.cream,
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
                // After handover the lifecycle status describes someone
                // else's step — show custody instead.
                if (!heldByMe)
                  const StatusChip(label: "Handed over", color: Ct.faded)
                else
                  _statusChip(batch["status"].toString()),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              "${batch["weight_kg"]} kg · ${fmtDate(batch["harvest_date"]?.toString())}",
              style: text.bodyMedium?.copyWith(color: Ct.faded),
            ),
            if (onPass != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onPass,
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text("Pass on"),
                ),
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

/// Empty state for non-farmer roles holding no batches.
class _EmptyHolder extends StatelessWidget {
  const _EmptyHolder();

  @override
  Widget build(BuildContext context) {
    return CtCard(
      child: Column(
        children: [
          const Icon(Icons.move_to_inbox, size: 40, color: Ct.faded),
          const SizedBox(height: 10),
          Text("Nothing with you yet",
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            "When someone hands a batch to you it appears here.",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Ct.faded),
          ),
        ],
      ),
    );
  }
}

/// Live queue of transfers addressed to the acting downstream role — the
/// collect-first landing surface for collector / processor / exporter.
class _IncomingQueue extends ConsumerWidget {
  const _IncomingQueue({required this.role, required this.scopeByRole});

  final String role;
  final bool scopeByRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final inbox = ref.watch(inboxProvider);
    return inbox.when(
      loading: () => const _LoadingCard(),
      error: (err, stack) => _ErrorCard(
        message: "Could not load incoming",
        retry: () => ref.invalidate(inboxProvider),
      ),
      data: (all) {
        final items = scopeByRole
            ? all
                .where((e) => (e["to_role"]?.toString() ?? "") == role)
                .toList()
            : all;
        if (items.isEmpty) {
          return CtCard(
            color: Ct.cream,
            child: Row(
              children: [
                const Icon(Icons.move_to_inbox_outlined,
                    color: Ct.faded, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    scopeByRole
                        ? "Nothing addressed to ${_queueRoleTitle(role)} right now."
                        : "Nothing to collect right now.",
                    style: text.bodyMedium?.copyWith(color: Ct.faded),
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            for (final item in items)
              _HomeIncomingCard(key: ValueKey(item["batch_id"]), item: item),
          ],
        );
      },
    );
  }

  static String _queueRoleTitle(String role) => switch (role) {
        "COLLECTOR" => "Collector",
        "PROCESSOR_L1" => "Processor L1",
        "PROCESSOR_L2" => "Processor L2",
        "EXPORTER" => "Exporter",
        _ => ctRoleLabel(role),
      };
}

/// Compact incoming card for Home; full detail stays one tap away.
class _HomeIncomingCard extends ConsumerStatefulWidget {
  const _HomeIncomingCard({super.key, required this.item});

  final Map<String, dynamic> item;

  @override
  ConsumerState<_HomeIncomingCard> createState() => _HomeIncomingCardState();
}

class _HomeIncomingCardState extends ConsumerState<_HomeIncomingCard> {
  bool _accepting = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final item = widget.item;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CtCard(
        color: Ct.leafSoft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item["batch_no"].toString(),
                    style:
                        text.titleMedium?.copyWith(fontFamily: Ct.display),
                  ),
                ),
                StatusChip(
                  label:
                      item["transfer_kind"] == "SALE" ? "For sale" : "Handover",
                  color:
                      item["transfer_kind"] == "SALE" ? Ct.quill : Ct.leaf,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "${item["weight_kg"]} kg · from ${item["from_name"]} · ${ctRoleLabel(item["from_role"].toString())}",
              style: text.bodyMedium?.copyWith(color: Ct.faded),
            ),
            const SizedBox(height: 12),
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
                const SizedBox(width: 10),
                Expanded(
                  child: CtButton(
                    label: "Accept",
                    icon: Icons.check,
                    loading: _accepting,
                    onPressed: () async {
                      setState(() => _accepting = true);
                      await acceptIncoming(context, ref,
                          item["batch_id"].toString());
                      if (mounted) setState(() => _accepting = false);
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
}

/// Banner shown when entries are queued in the outbox: count + manual
/// "Sync now" trigger (flutter-plan §3.2).
class _SyncBanner extends ConsumerWidget {
  const _SyncBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingSyncCountProvider);
    final count = pending.maybeWhen(data: (c) => c, orElse: () => 0);
    if (count == 0) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: CtCard(
        color: Ct.quillSoft,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.cloud_upload, color: Ct.cinnamon, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "$count item${count == 1 ? "" : "s"} waiting to sync",
                style: text.titleMedium?.copyWith(color: Ct.cinnamon),
              ),
            ),
            CtButton(
              label: "Sync now",
              onPressed: () => ref.read(syncWorkerProvider).drain(),
            ),
          ],
        ),
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
    final items = inbox.maybeWhen(data: (l) => l, orElse: () => const <Map<String, dynamic>>[]);
    final count = items.length;
    if (count == 0) return const SizedBox.shrink();

    final auth = ref.watch(authProvider);
    final user = auth is SignedIn ? auth.user : null;
    final userRoles = user?.roles ?? const <String>[];
    final activeRole = ref.watch(activeRoleProvider);

    final firstItem = items.firstOrNull;
    final targetRole = firstItem?["to_role"]?.toString();

    void goToInbox() {
      if (targetRole != null &&
          targetRole != activeRole &&
          userRoles.contains(targetRole)) {
        ref.read(activeRoleProvider.notifier).state = targetRole;
      } else if (activeRole == "FARMER" && userRoles.isNotEmpty) {
        final nonFarmer = userRoles.firstWhere((r) => r != "FARMER", orElse: () => "");
        if (nonFarmer.isNotEmpty) {
          ref.read(activeRoleProvider.notifier).state = nonFarmer;
        }
      }
      context.go("/inbox");
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: CtCard(
        color: Ct.quillSoft,
        onTap: goToInbox,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.move_to_inbox, color: Ct.cinnamon, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "$count batch${count == 1 ? "" : "es"} waiting for you${targetRole != null && targetRole != activeRole ? " (${ctRoleLabel(targetRole)})" : ""}",
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
