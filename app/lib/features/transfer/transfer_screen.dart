import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../app/theme.dart";
import "../../core/auth/auth_state.dart";
import "../../core/data/repositories.dart";
import "../../core/widgets/ct_widgets.dart";
import "../inbox/inbox_screen.dart";

/// Mirrors the backend TRANSFER_MATRIX (plan §3.4) so this screen can explain
/// eligibility up front instead of surfacing it as a server error later.
const _transferMatrix = <String, List<String>>{
  "FARMER": ["COLLECTOR", "PROCESSOR_L1"],
  "COLLECTOR": ["COLLECTOR", "PROCESSOR_L1", "PROCESSOR_L2", "EXPORTER"],
  "PROCESSOR_L1": ["COLLECTOR", "PROCESSOR_L2", "EXPORTER"],
  "PROCESSOR_L2": ["COLLECTOR", "EXPORTER"],
  "EXPORTER": [],
};

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key, required this.batchId});

  final String batchId;

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _searchCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  List<Map<String, dynamic>> _recipients = [];

  /// The user's own OTHER roles that the current holding role may legally
  /// transfer to (matrix-filtered) — the self-handover targets.
  List<String> _selfRoleTargets() {
    final auth = ref.read(authProvider);
    if (auth is! SignedIn) return const [];
    final batchAsync = ref.read(batchByIdProvider(widget.batchId));
    final holderRole =
        batchAsync.asData?.value["current_holder_role"]?.toString();
    final allowed = _transferMatrix[holderRole] ?? const <String>[];
    final mine = auth.user.roles
        .where((r) => r != holderRole && allowed.contains(r))
        .toList()
      ..sort();
    return mine;
  }

  String? get _meId {
    final auth = ref.read(authProvider);
    return auth is SignedIn ? auth.user.id : null;
  }
  Map<String, dynamic>? _selected;
  String _kind = "SALE";
  String? _roleFilter;
  bool _searching = false;
  bool _sending = false;
  String? _error;
  /// Last query the server actually answered — lets the UI tell "still
  /// searching" apart from "search finished, nobody matched".
  String _searchedFor = "";

  Set<String> _allowedRoles() {
    final batchAsync = ref.read(batchByIdProvider(widget.batchId));
    final holderRole = batchAsync.asData?.value["current_holder_role"]?.toString();
    if (holderRole != null && _transferMatrix.containsKey(holderRole)) {
      return (_transferMatrix[holderRole] ?? const <String>[]).toSet();
    }
    final activeRole = ref.read(activeRoleProvider);
    if (_transferMatrix.containsKey(activeRole)) {
      return (_transferMatrix[activeRole] ?? const <String>[]).toSet();
    }
    final auth = ref.read(authProvider);
    final roles = auth is SignedIn ? auth.user.roles : const <String>[];
    return {for (final r in roles) ..._transferMatrix[r] ?? const <String>[]};
  }

  /// Same thresholds as GET /transfers/recipients: 3+ characters of name,
  /// 6+ digits of mobile. Shorter input never reaches the server.
  (bool nameOk, bool mobileOk) _searchMode(String q) {
    final t = q.trim();
    final letters =
        RegExp(r"[a-zA-Z\u0D80-\u0DFF\u0B80-\u0BFF]").allMatches(t).length;
    final digits = t.replaceAll(RegExp(r"[^0-9]"), "");
    final mobileOnly = t.replaceFirst(RegExp(r"^\+"), "");
    return (
      letters >= 3,
      digits.length >= 6 && !RegExp(r"[a-zA-Z]").hasMatch(mobileOnly),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final query = q.trim();
    setState(() => _searching = true);
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get("/transfers/recipients", query: {
        "q": query,
        if (_roleFilter != null) "role": _roleFilter,
      });
      setState(() {
        _recipients =
            (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    } catch (_) {
      // keep previous list
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
          _searchedFor = query;
        });
      }
    }
  }

  Future<void> _send() async {
    if (_selected == null) {
      setState(() => _error = "Choose who gets this batch");
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final toUserId = _selected!["id"].toString();
      final toRole = _selected!["role"]?.toString();
      final body = <String, dynamic>{
        "to_user_id": toUserId,
        "transfer_kind": _kind,
        "price_lkr": _kind == "SALE" ? double.tryParse(_priceCtrl.text) : null,
        "notes": _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      };
      if (toRole != null) {
        body["to_role"] = toRole;
      }
      await api.post("/batches/${widget.batchId}/transfer", body: body);
      // Immediately lock the batch in local drift DB so the sender cannot sell or handover again
      await ref.read(batchesRepoProvider).updateBatchLocalTransfer(
        batchId: widget.batchId,
        toUserId: toUserId,
        toRole: toRole,
      );
      ref.invalidate(batchesProvider);
      ref.invalidate(inboxProvider);
      ref.invalidate(batchByIdProvider(widget.batchId));
      try {
        await ref.read(batchesRepoProvider).pullBatches();
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Transfer created — batch locked in transit"),
            backgroundColor: Ct.leaf,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go("/batches");
      }
    } catch (e) {
      setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains("NOT_HOLDER")) return "You don't hold this batch anymore.";
    if (s.contains("TRANSFER_NOT_ALLOWED")) {
      return "Not allowed to transfer to this person.";
    }
    if (s.contains("NOT_TRANSFERABLE")) return "This batch can't be transferred now.";
    if (s.contains("NETWORK") || s.contains("TIMEOUT")) {
      return "No internet connection. Try again.";
    }
    return "Could not create transfer. Try again.";
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final query = _searchCtrl.text.trim();
    final (nameOk, mobileOk) = _searchMode(query);
    final searchable = nameOk || mobileOk;
    final settled = _searchedFor == query;
    final eligible = _allowedRoles().toList()..sort();

    final batchAsync = ref.watch(batchByIdProvider(widget.batchId));
    final batchData = batchAsync.asData?.value;
    final batchStatus = batchData?["status"]?.toString();
    final auth = ref.watch(authProvider);
    final myId = auth is SignedIn ? auth.user.id : null;
    final holderId = batchData?["current_holder_id"]?.toString();
    final isLocked = batchStatus == "IN_TRANSIT" ||
        (holderId != null && myId != null && holderId != myId);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, color: Ct.ink),
          onPressed: () => ctNavigateBack(context, fallback: "/batch/${widget.batchId}"),
        ),
        title: Text("Sell / Hand over", style: text.titleLarge),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Ct.pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLocked) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Ct.quillSoft,
                    borderRadius: BorderRadius.circular(Ct.radiusSm),
                    border: Border.all(color: Ct.cinnamon.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, color: Ct.cinnamon, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "This batch is locked (In Transit / Transferred) and cannot be transferred again.",
                          style: text.bodyMedium?.copyWith(
                            color: Ct.cinnamon,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Text("Who gets it?", style: text.headlineMedium),
              const SizedBox(height: 10),
              _Eligibility(roles: eligible),
              // With several eligible roles, let the sender browse one
              // receiver role at a time instead of guessing names.
              if (eligible.length > 1) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _roleChip(null, "All"),
                    for (final r in eligible) _roleChip(r, _roleLabel(r)),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              CtField(
                label: "Search by mobile or name",
                controller: _searchCtrl,
                hint: "+94 77 … or Nimal",
                prefix: const Icon(Icons.search, color: Ct.faded),
                onChanged: (v) => _debounceSearch(v),
              ),
              const SizedBox(height: 8),
              Text(
                "For privacy there is no full directory — people appear as you type.",
                style: text.labelMedium?.copyWith(color: Ct.faded),
              ),
              const SizedBox(height: 16),
              // Multi-role user: offer handing the batch to one of their own
              // other roles (e.g. farmer hands to their own processor) —
              // same IN_TRANSIT → accept flow as any transfer.
              if (_selfRoleTargets().isNotEmpty) ...[
                Text(
                  "Your other roles",
                  style: text.labelMedium?.copyWith(color: Ct.faded),
                ),
                const SizedBox(height: 8),
                for (final entry in _selfRoleTargets())
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CtCard(
                      onTap: isLocked
                          ? null
                          : () => setState(() => _selected = {
                                "id": _meId,
                                "name": "Me",
                                "role": entry,
                                "mobile": "self handover",
                              }),
                      color: _selected?["role"] == entry && _selected?["id"] == _meId
                          ? Ct.leafSoft
                          : Ct.paper,
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 20,
                            backgroundColor: Ct.quill,
                            child:
                                Icon(Icons.sync_alt, color: Ct.paper, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Hand over to my ${_roleLabel(entry)}",
                                    style: text.titleMedium),
                                Text(
                                  "Switch this batch to your own ${_roleLabel(entry)} role",
                                  style: text.bodyMedium
                                      ?.copyWith(color: Ct.faded),
                                ),
                              ],
                            ),
                          ),
                          if (_selected?["role"] == entry &&
                              _selected?["id"] == _meId)
                            const Icon(Icons.check_circle, color: Ct.leaf),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
              ],
              if (_recipients.isNotEmpty) ...[
                if (_searching)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    color: Ct.cinnamon,
                    backgroundColor: Ct.line,
                  ),
                const SizedBox(height: 10),
                for (final r in _recipients)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CtCard(
                      onTap: isLocked ? null : () => setState(() => _selected = r),
                      color: (_selected?["id"] == r["id"] &&
                              _selected?["role"] == r["role"])
                          ? Ct.leafSoft
                          : Ct.paper,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Ct.cinnamon,
                            child: Text(
                              r["name"].toString().isNotEmpty
                                  ? r["name"].toString()[0].toUpperCase()
                                  : "?",
                              style: text.titleMedium
                                  ?.copyWith(color: Ct.paper),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r["name"].toString(),
                                    style: text.titleMedium),
                                Text(
                                  "${_roleLabel(r["role"].toString())} · ${r["mobile"]}",
                                  style: text.bodyMedium
                                      ?.copyWith(color: Ct.faded),
                                ),
                              ],
                            ),
                          ),
                          if (_selected?["id"] == r["id"] &&
                              _selected?["role"] == r["role"])
                            const Icon(Icons.check_circle, color: Ct.leaf),
                        ],
                      ),
                    ),
                  ),
              ] else if (query.isEmpty)
                CtCard(
                  color: Ct.quillSoft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_search,
                              color: Ct.cinnamon, size: 22),
                          const SizedBox(width: 10),
                          Text("Find the receiver",
                              style: text.titleMedium
                                  ?.copyWith(color: Ct.cinnamon)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Type at least 3 letters of their name, or 6+ digits of their mobile number, then pick them from the results.",
                        style: text.bodyMedium?.copyWith(color: Ct.faded),
                      ),
                    ],
                  ),
                )
              else if (!searchable)
                CtCard(
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note, color: Ct.faded, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Keep typing — at least 3 letters of a name or 6 digits of a mobile.",
                          style: text.bodyMedium?.copyWith(color: Ct.faded),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_searching || !settled)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child:
                        CircularProgressIndicator(color: Ct.cinnamon, strokeWidth: 2.4),
                  ),
                )
              else
                CtCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("No one found for “$query”",
                          style: text.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        "Check the spelling, or try more digits of their mobile number. Only people allowed to receive from you are shown.",
                        style: text.bodyMedium?.copyWith(color: Ct.faded),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 22),
              Text("Type", style: text.titleMedium),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _KindCard(
                      label: "Sale",
                      icon: Icons.payments_outlined,
                      selected: _kind == "SALE",
                      onTap: () => setState(() => _kind = "SALE"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _KindCard(
                      label: "Hand over",
                      icon: Icons.handshake_outlined,
                      selected: _kind == "HANDOFF",
                      onTap: () => setState(() => _kind = "HANDOFF"),
                    ),
                  ),
                ],
              ),
              if (_kind == "SALE") ...[
                const SizedBox(height: 18),
                CtField(
                  label: "Price (LKR)",
                  controller: _priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  hint: "45000",
                  prefix: const Icon(Icons.money_outlined, color: Ct.faded),
                ),
              ],
              const SizedBox(height: 18),
              CtField(
                label: "Notes (optional)",
                controller: _notesCtrl,
                hint: "Paid cash on collection",
              ),
              if (_selected != null) ...[
                const SizedBox(height: 20),
                CtCard(
                  color: Ct.leafSoft,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Ct.leaf, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "To ${_selected!["name"]} · ${_roleLabel(_selected!["role"].toString())}",
                          style: text.titleMedium?.copyWith(color: Ct.leaf),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Ct.claySoft,
                    borderRadius: BorderRadius.circular(Ct.radiusSm),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Ct.clay, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: text.bodyMedium?.copyWith(color: Ct.clay),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: CtButton(
                  label: isLocked ? "Batch Locked" : "Confirm Transfer",
                  icon: isLocked ? Icons.lock : Icons.check_circle_outline,
                  enabled: !isLocked,
                  loading: _sending,
                  onPressed: isLocked ? null : _send,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  DateTime _lastSearch = DateTime.now();
  void _debounceSearch(String q) {
    final now = DateTime.now();
    _lastSearch = now;
    Future.delayed(const Duration(milliseconds: 350), () {
      if (now == _lastSearch) _search(q);
    });
  }

  void _setRoleFilter(String? role) {
    setState(() {
      _roleFilter = role;
      _recipients = [];
      _searchedFor = "";
    });
    final mode = _searchMode(_searchCtrl.text);
    if (mode.$1 || mode.$2) _debounceSearch(_searchCtrl.text);
  }

  Widget _roleChip(String? code, String label) {
    final selected = _roleFilter == code;
    return GestureDetector(
      onTap: () => _setRoleFilter(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Ct.cinnamon : Ct.paper,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? Ct.cinnamon : Ct.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: Ct.body,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Ct.paper : Ct.ink,
          ),
        ),
      ),
    );
  }
}

/// Sender-side copy of the role matrix: chips naming the roles allowed to
/// receive from the current user.
class _Eligibility extends StatelessWidget {
  const _Eligibility({required this.roles});

  final List<String> roles;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (roles.isEmpty) {
      return CtCard(
        color: Ct.claySoft,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.flag, color: Ct.clay, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Export is the final step — batches you hold can no longer be transferred.",
                style: text.bodyMedium?.copyWith(color: Ct.clay),
              ),
            ),
          ],
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text("Can go to", style: text.labelMedium?.copyWith(color: Ct.faded)),
        for (final r in roles) StatusChip(label: _roleLabel(r), color: Ct.cinnamon),
      ],
    );
  }
}

String _roleLabel(String role) => ctRoleLabel(role);

class _KindCard extends StatelessWidget {
  const _KindCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return CtCard(
      onTap: onTap,
      color: selected ? Ct.quillSoft : Ct.paper,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(icon, size: 30, color: selected ? Ct.cinnamon : Ct.faded),
          const SizedBox(height: 8),
          Text(
            label,
            style: text.titleMedium?.copyWith(
              color: selected ? Ct.cinnamon : Ct.ink,
            ),
          ),
        ],
      ),
    );
  }
}
