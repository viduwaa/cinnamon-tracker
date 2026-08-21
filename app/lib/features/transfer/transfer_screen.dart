import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../app/theme.dart";
import "../../core/auth/auth_state.dart";
import "../../core/widgets/ct_widgets.dart";
import "../home/home_screen.dart";
import "../inbox/inbox_screen.dart";

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
  Map<String, dynamic>? _selected;
  String _kind = "SALE";
  bool _searching = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search("");
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() => _searching = true);
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get("/transfers/recipients", query: {"q": q});
      setState(() {
        _recipients =
            (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    } catch (_) {
      // keep previous list
    } finally {
      if (mounted) setState(() => _searching = false);
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
      await api.post("/batches/${widget.batchId}/transfer", body: {
        "to_user_id": _selected!["id"],
        "transfer_kind": _kind,
        "price_lkr": _kind == "SALE" ? double.tryParse(_priceCtrl.text) : null,
        "notes": _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      });
      ref.invalidate(batchesProvider);
      ref.invalidate(inboxProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Transfer created"),
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, color: Ct.ink),
          onPressed: () => context.pop(),
        ),
        title: Text("Sell / Hand over", style: text.titleLarge),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Ct.pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Who gets it?", style: text.headlineMedium),
              const SizedBox(height: 14),
              CtField(
                label: "Search by mobile or name",
                controller: _searchCtrl,
                hint: "+94 77 … or Nimal",
                prefix: const Icon(Icons.search, color: Ct.faded),
                onChanged: (v) => _debounceSearch(v),
              ),
              const SizedBox(height: 14),
              if (_searching)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child:
                        CircularProgressIndicator(color: Ct.cinnamon, strokeWidth: 2.4),
                  ),
                )
              else if (_recipients.isEmpty)
                CtCard(
                  child: Text("No matching people",
                      style: text.bodyMedium?.copyWith(color: Ct.faded)),
                )
              else
                Column(
                  children: [
                    for (final r in _recipients)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: CtCard(
                          onTap: () => setState(() => _selected = r),
                          color: _selected?["id"] == r["id"]
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
                                    Text(r["name"].toString(), style: text.titleMedium),
                                    Text(
                                      "${_roleLabel(r["role"].toString())} · ${r["mobile"]}",
                                      style: text.bodyMedium
                                          ?.copyWith(color: Ct.faded),
                                    ),
                                  ],
                                ),
                              ),
                              if (_selected?["id"] == r["id"])
                                const Icon(Icons.check_circle, color: Ct.leaf),
                            ],
                          ),
                        ),
                      ),
                  ],
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
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: text.bodyMedium?.copyWith(color: Ct.clay)),
              ],
              const SizedBox(height: 24),
              CtButton(
                label: "Confirm Transfer",
                icon: Icons.check_circle_outline,
                loading: _sending,
                onPressed: _send,
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

  String _roleLabel(String role) => switch (role) {
        "FARMER" => "Farmer",
        "PROCESSOR_L1" => "Processor L1",
        "COLLECTOR" => "Collector",
        "PROCESSOR_L2" => "Processor L2",
        "EXPORTER" => "Exporter",
        _ => role,
      };
}

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
