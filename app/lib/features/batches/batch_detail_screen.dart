import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";
import "package:url_launcher/url_launcher.dart";
import "../../app/theme.dart";
import "../../core/api/api_exception.dart";
import "../../core/auth/auth_state.dart";
import "../../core/data/repositories.dart";
import "../../core/widgets/ct_widgets.dart";
import "../inbox/inbox_screen.dart";

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
          onPressed: () => ctNavigateBack(context, fallback: "/batches"),
        ),
        title: Text("Batch", style: text.titleLarge),
      ),
      body: SafeArea(
        child: batch.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: Ct.cinnamon)),
          error: (err, stack) => Center(
            child: Text("Could not load batch", style: text.bodyMedium),
          ),
          data: (b) {
            final chain = (b["chain"] as List? ?? const [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            final origin = b["origin"] == null
                ? null
                : Map<String, dynamic>.from(b["origin"] as Map);
            final verification = b["verification"] == null
                ? const <String, dynamic>{}
                : Map<String, dynamic>.from(b["verification"] as Map);
            final auth = ref.watch(authProvider);
            final myId = auth is SignedIn ? auth.user.id : null;
            final isMine =
                myId != null && b["current_holder_id"]?.toString() == myId;
            final canTransfer = isMine &&
                holderActionStatuses.contains(b["status"].toString());
            final holder = b["current_holder"] as Map?;
            final holderRole = b["current_holder_role"]?.toString() ??
                (holder?["role"]?.toString() ?? "");
            final canProcess = isMine &&
                holderActionStatuses.contains(b["status"].toString()) &&
                (holderRole == "PROCESSOR_L1" || holderRole == "PROCESSOR_L2");
            final canExport = isMine &&
                holderActionStatuses.contains(b["status"].toString()) &&
                holderRole == "EXPORTER";
            // Custody chip is acting-role aware, matching the Batches tab.
            final activeRole = ref.watch(activeRoleProvider);
            final accountRoles =
                auth is SignedIn ? auth.user.roles : const ["FARMER"];
            final actingRole = accountRoles.contains(activeRole)
                ? activeRole
                : (accountRoles.firstOrNull ?? "FARMER");
            final heldAsActing = ctHeldUnderRole(
              batch: b,
              myId: myId,
              actingRole: actingRole,
            );
            // The newest handover tells us whether this was a sale.
            final lastTransfer = chain.lastWhere(
              (e) => e["event_type"].toString() == "TRANSFERRED",
              orElse: () => const {},
            );
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
                          if (isMine)
                            StatusChip(
                              label: heldAsActing
                                  ? "Assigned as ${ctRoleLabel(holderRole.isNotEmpty ? holderRole : "FARMER")}"
                                  // Held under a different of my roles — state
                                  // true custody and the action that fixes it.
                                  : "Held as ${ctRoleLabel(holderRole.isNotEmpty ? holderRole : "FARMER")} · acting as ${ctRoleLabel(actingRole)}",
                              color: Ct.leaf,
                            )
                          else if (holderRole.isNotEmpty)
                            StatusChip(
                              label: "With ${ctRoleLabel(holderRole)}",
                              color: Ct.faded,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
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
                                    // Human-readable origin line: district
                                    // name, land size, address when present.
                                    [
                                      if ((origin["district"] ?? origin["area_code"])
                                          ?.toString()
                                          .isNotEmpty ==
                                      true)
                                        "District ${origin["district"] ?? origin["area_code"]}",
                                      if (origin["size"]?.toString().isNotEmpty == true)
                                        origin["size"].toString(),
                                      if (origin["address"]?.toString().isNotEmpty == true)
                                        origin["address"].toString(),
                                    ].join(" · "),
                                    style: text.bodyMedium
                                        ?.copyWith(color: Ct.faded),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Harvest-origin proof: when the farmer chose to expose
                        // exact coordinates, the server sends lat/lng here —
                        // show the pinned map as authenticity evidence.
                        if (origin["location"] is Map) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(Ct.radiusSm),
                            child: SizedBox(
                              height: 140,
                              width: double.infinity,
                              child: GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: LatLng(
                                    (origin["location"]["lat"] as num).toDouble(),
                                    (origin["location"]["lng"] as num).toDouble(),
                                  ),
                                  zoom: 14,
                                ),
                                markers: {
                                  Marker(
                                    markerId: const MarkerId("origin"),
                                    position: LatLng(
                                      (origin["location"]["lat"] as num)
                                          .toDouble(),
                                      (origin["location"]["lng"] as num)
                                          .toDouble(),
                                    ),
                                    infoWindow: InfoWindow(
                                      title: origin["farm_name"]?.toString() ??
                                          "Harvest origin",
                                    ),
                                  ),
                                },
                                scrollGesturesEnabled: false,
                                zoomGesturesEnabled: false,
                                tiltGesturesEnabled: false,
                                rotateGesturesEnabled: false,
                                myLocationButtonEnabled: false,
                                zoomControlsEnabled: false,
                                mapToolbarEnabled: false,
                                liteModeEnabled: true,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.verified_outlined,
                                  size: 14, color: Ct.leaf),
                              const SizedBox(width: 4),
                              Text(
                                "Harvest origin pinned by the farmer at creation",
                                style: text.labelSmall
                                    ?.copyWith(color: Ct.faded),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                // Tamper-evidence banner — server-recomputed hash chain +
                // Bitcoin anchor state, shared with the public verify portal.
                _VerificationBanner(
                  verification: verification,
                  batchNo: b["batch_no"]?.toString() ?? "",
                  onShowProof: () => _showProofSheet(
                    context,
                    ref,
                    verification: verification,
                    chain: chain,
                    batchNo: b["batch_no"]?.toString() ?? "",
                  ),
                ),
                const SizedBox(height: 16),
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
                if (canProcess) ...[
                  SizedBox(
                    width: double.infinity,
                    child: CtButton(
                      label: "Record processing",
                      icon: Icons.precision_manufacturing,
                      onPressed: () => context.push("/process/$batchId"),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (canExport) ...[
                  SizedBox(
                    width: double.infinity,
                    child: CtButton(
                      label: "Merge into export lot",
                      icon: Icons.local_shipping,
                      onPressed: () => context.push("/lots/new"),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Grill Q3: the exporter may renumber a held batch before
                  // export — default appends /EX, or a custom EX-pattern no.
                  SizedBox(
                    width: double.infinity,
                    child: CtButton(
                      label: "Rename batch (/EX)",
                      icon: Icons.label,
                      secondary: true,
                      onPressed: () => _showRenameSheet(context, ref, batchId),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (canTransfer) ...[
                  SizedBox(
                    width: double.infinity,
                    child: CtButton(
                      label: "Sell / Hand over",
                      icon: Icons.swap_horiz,
                      onPressed: () => context.push("/transfer/$batchId"),
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else if (b["status"].toString() == "IN_TRANSIT") ...[
                  if (isMine) ...[
                    CtCard(
                      color: Ct.leafSoft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.inbox_outlined,
                                  color: Ct.leaf, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Incoming Transfer",
                                  style: text.titleMedium?.copyWith(
                                    color: Ct.leaf,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "This batch was transferred to you as ${ctRoleLabel(holderRole.isNotEmpty ? holderRole : "Recipient")}. Accept it to unlock and take custody.",
                            style: text.bodyMedium?.copyWith(color: Ct.ink),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: CtButton(
                              label: "Accept Transfer",
                              icon: Icons.check,
                              onPressed: () => acceptIncoming(context, ref, batchId),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    CtCard(
                      color: Ct.quillSoft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.lock_clock,
                                  color: Ct.cinnamon, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Batch Locked · In Transit",
                                  style: text.titleMedium?.copyWith(
                                    color: Ct.cinnamon,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            holder != null
                                ? "Transferred to ${holder["name"]} (${ctRoleLabel(holder["role"]?.toString() ?? "")}). Waiting for the receiver to accept."
                                : "This batch is currently in transit. Waiting for the receiver to accept.",
                            style: text.bodyMedium?.copyWith(color: Ct.faded),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ] else if (!isMine) ...[
                  CtCard(
                    color: Ct.quillSoft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.swap_horiz,
                                color: Ct.cinnamon, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                lastTransfer["summary"]?.toString() ??
                                    "No longer with you",
                                style: text.titleMedium
                                    ?.copyWith(color: Ct.cinnamon),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          holder != null
                              ? "Now with ${holder["name"]} (${ctRoleLabel(holder["role"]?.toString() ?? "")})."
                              : "This batch has moved on in the chain of custody.",
                          style:
                              text.bodyMedium?.copyWith(color: Ct.faded),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: CtButton(
                    label: "Show QR",
                    icon: Icons.qr_code,
                    secondary: true,
                    onPressed: () => context.push("/qr/show/$batchId"),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Exporter renumbering (grill Q3): empty input → append /EX; a custom
  /// number must match the EX pattern. Old number stays resolvable via the
  /// server-side alias table, and a RENAMED event lands on the chain.
  Future<void> _showRenameSheet(
    BuildContext context,
    WidgetRef ref,
    String batchId,
  ) {
    final customCtrl = TextEditingController();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          Ct.pad, Ct.pad, Ct.pad, Ct.pad + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Rename batch", style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              "Leave empty to add /EX to the current number. The link to the origin batch is always kept.",
              style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(color: Ct.faded),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: customCtrl,
              decoration: const InputDecoration(
                hintText: "GM-172-01-2026-EX-ACME",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            CtButton(
              label: "Save number",
              icon: Icons.check,
              onPressed: () async {
                try {
                  final api = ref.read(apiClientProvider);
                  final custom = customCtrl.text.trim().toUpperCase();
                  final data = await api.post("/batches/$batchId/rename", body: {
                    "batch_no": custom.isEmpty ? null : custom,
                  });
                  final m = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
                  await ref.read(batchesRepoProvider).updateBatchLocalProcess(
                        batchId: batchId,
                        batchNo: m["batch_no"]?.toString(),
                        stageSuffix: null,
                        weightKg: 0,
                      );
                  ref.invalidate(batchByIdProvider(batchId));
                  ref.invalidate(batchesProvider);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                } on ApiException catch (e) {
                  if (sheetContext.mounted) {
                    ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(
                      content: Text(
                        e.code == "BATCH_NO_TAKEN"
                            ? "That number is already used."
                            : "Could not rename — try again.",
                      ),
                    ));
                  }
                } catch (_) {
                  if (sheetContext.mounted) {
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(content: Text("Could not rename — try again.")),
                    );
                  }
                }
              },
            ),
          ],
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
        "RENAMED" => Ct.faded,
        "EXPORTED" => Ct.bark,
        _ => Ct.faded,
      };

  IconData _icon(String type) => switch (type) {
        "CREATED" => Icons.spa,
        "TRANSFERRED" => Icons.swap_horiz,
        "PROCESSED" => Icons.precision_manufacturing,
        "RENAMED" => Icons.label,
        "EXPORTED" => Icons.flight_takeoff,
        _ => Icons.circle,
      };

  String _roleLabel(String role) => ctRoleLabel(role);

  String _fmtDate(String? iso) {
    if (iso == null) return "";
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return "${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, "0")}:${d.minute.toString().padLeft(2, "0")}";
  }
}

/// Verdict banner above the chain timeline. Colors carry the meaning:
/// green = hash chain intact AND every event Bitcoin-anchored,
/// amber = chain intact, anchoring still pending,
/// red = recomputed hash chain broken (evidence of tampering).
class _VerificationBanner extends StatelessWidget {
  const _VerificationBanner({
    required this.verification,
    required this.batchNo,
    required this.onShowProof,
  });

  final Map<String, dynamic> verification;
  final String batchNo;
  final VoidCallback onShowProof;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final verdict = verification["verdict"]?.toString() ?? "PENDING";
    final (icon, color, title, body) = switch (verdict) {
      "AUTHENTIC" => (
        Icons.verified,
        Ct.leaf,
        "Blockchain-verified",
        "Hash chain intact · every event anchored to Bitcoin",
      ),
      "TAMPERED" => (
        Icons.gpp_bad,
        Ct.clay,
        "Tampering detected",
        "Custody records fail hash verification",
      ),
      _ => (
        Icons.schedule,
        Ct.quill,
        "Verification pending",
        "Records valid · Bitcoin anchoring in progress",
      ),
    };
    final bg = verdict == "TAMPERED"
        ? Ct.claySoft
        : verdict == "AUTHENTIC"
            ? Ct.leafSoft
            : Ct.quillSoft;

    return InkWell(
      onTap: onShowProof,
      borderRadius: BorderRadius.circular(Ct.radius),
      child: CtCard(
        color: bg,
        child: Row(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleMedium?.copyWith(color: color)),
                  const SizedBox(height: 2),
                  Text(body,
                      style: text.bodySmall?.copyWith(color: Ct.faded)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Ct.faded),
          ],
        ),
      ),
    );
  }
}

/// Proof sheet: the raw evidence behind the verdict — per-event hashes,
/// anchor attestations, merkle roots — copyable and independently checkable
/// against the public verify portal.
Future<void> _showProofSheet(
  BuildContext context,
  WidgetRef ref, {
  required Map<String, dynamic> verification,
  required List<Map<String, dynamic>> chain,
  required String batchNo,
}) {
  final text = Theme.of(context).textTheme;
  final anchors = (verification["anchors"] as List? ?? const [])
      .map((a) => Map<String, dynamic>.from(a as Map))
      .toList();
  const verifyBase = String.fromEnvironment(
    "VERIFY_BASE_URL",
    defaultValue: "https://api-cinnamon.viduwa.dev/verify",
  );
  final verifyUrl = "$verifyBase/$batchNo";

  return showModalBottomSheet(
    context: context,
    backgroundColor: Ct.paper,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Ct.radius)),
    ),
    builder: (sheetContext) => SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(Ct.pad),
          children: [
            Row(
              children: [
                const Icon(Icons.fact_check, color: Ct.cinnamon),
                const SizedBox(width: 10),
                Expanded(
                  child: Text("Blockchain proof",
                      style: text.titleLarge?.copyWith(fontFamily: Ct.display)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "Any party can recompute these hashes and check the Bitcoin timestamps.",
              style: text.bodySmall?.copyWith(color: Ct.faded),
            ),
            const SizedBox(height: 16),
            Text("Anchors (${anchors.length})", style: text.titleMedium),
            const SizedBox(height: 8),
            if (anchors.isEmpty)
              Text(
                "Not yet anchored — the nightly job submits every event's hash to OpenTimestamps calendars, which anchor to Bitcoin within ~24h.",
                style: text.bodyMedium?.copyWith(color: Ct.faded),
              )
            else
              for (final a in anchors)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CtCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Bitcoin · ${a["status"]?.toString() ?? "?"}",
                          style: text.titleSmall
                              ?.copyWith(color: Ct.leaf, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        _proofRow(context, "Merkle root",
                            a["merkle_root"]?.toString()),
                        _proofRow(context, "Attestation",
                            a["tx_hash"]?.toString()),
                        _proofRow(context, "Anchored at",
                            a["anchored_at"]?.toString()),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 10),
            Text("Event hashes (${chain.length})", style: text.titleMedium),
            const SizedBox(height: 8),
            for (final e in chain)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CtCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e["summary"]?.toString() ??
                            e["event_type"]?.toString() ??
                        "Event",
                        style: text.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      _proofRow(context, "SHA-256", e["event_hash"]?.toString()),
                      if (e["anchored"] == true)
                        const Row(
                          children: [
                            Icon(Icons.verified, size: 13, color: Ct.leaf),
                            SizedBox(width: 4),
                            Text("Anchored",
                                style: TextStyle(
                                    fontSize: 12, color: Ct.leaf)),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 10),
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
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
}

/// One labelled hash row with a copy button.
Widget _proofRow(BuildContext context, String label, String? value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Text("$label:", style: const TextStyle(fontSize: 12, color: Ct.faded)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value ?? "—",
            style: const TextStyle(
                fontSize: 12, fontFamily: "monospace", color: Ct.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.copy, size: 15, color: Ct.faded),
          onPressed: value == null
              ? null
              : () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("$label copied"),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
        ),
      ],
    ),
  );
}
