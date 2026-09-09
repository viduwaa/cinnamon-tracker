import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../app/theme.dart";
import "../../core/api/api_exception.dart";
import "../../core/auth/auth_state.dart";
import "../../core/data/repositories.dart";
import "../../core/widgets/ct_widgets.dart";

/// Exporter lot builder (api-spec §6): merge held batches into one container
/// lot and export it in one step. The lot gets a number
/// `EX-SSS-YYYY-EXP-<exporterCode>`; every merged batch keeps its own history
/// and stays linked to the lot — the QR of the lot shows all origins.
class LotBuilderScreen extends ConsumerStatefulWidget {
  const LotBuilderScreen({super.key});

  @override
  ConsumerState<LotBuilderScreen> createState() => _LotBuilderScreenState();
}

class _LotBuilderScreenState extends ConsumerState<LotBuilderScreen> {
  final _buyerCtrl = TextEditingController();
  final _containerCtrl = TextEditingController();
  final Set<String> _selected = {};
  String? _error;
  bool _sending = false;
  List<Map<String, dynamic>>? _lotsThisYear;
  late DateTime _shipmentDate = DateTime.now();

  @override
  void dispose() {
    _buyerCtrl.dispose();
    _containerCtrl.dispose();
    super.dispose();
  }

  /// Per-exporter yearly sequence. Local count of synced lots this year + 1 —
  /// collisions surface as 409 LOT_NO_TAKEN and the user increments.
  String _nextLotNo() {
    final auth = ref.read(authProvider);
    final code = auth is SignedIn ? (auth.user.exporterCode ?? "A") : "A";
    final year = DateTime.now().year;
    int maxSeq = 0;
    for (final raw in _lotsThisYear ?? const []) {
      final no = raw["batch_no"]?.toString() ?? "";
      final m = lotNoSeqPattern.firstMatch(no);
      if (m != null && m.group(1) == year.toString()) {
        final seq = int.tryParse(m.group(2)!);
        if (seq != null && seq > maxSeq) maxSeq = seq;
      }
    }
    final next = (maxSeq + 1).toString().padLeft(3, "0");
    return "EX-$next-$year-EXP-$code";
  }

  Future<void> _export() async {
    if (_selected.isEmpty) {
      setState(() => _error = "Select at least one batch");
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final lotNo = _nextLotNo();
      final body = <String, dynamic>{
        "batch_ids": _selected.toList(),
        "lot_no": lotNo,
        "shipment_date": _shipmentDate.toIso8601String().substring(0, 10),
        "buyer_name": _buyerCtrl.text.trim().isEmpty ? null : _buyerCtrl.text.trim(),
        "container_no": _containerCtrl.text.trim().isEmpty
            ? null
            : _containerCtrl.text.trim().toUpperCase(),
      };
      final data = await api.post("/lots", body: body);
      final m = Map<String, dynamic>.from(data as Map);
      ref.invalidate(batchesProvider);
      ref.invalidate(myLotsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Exported ${m["batch_nos"]?.length ?? _selected.length} batch(es) as lot ${m["lot_no"] ?? lotNo}",
            ),
            backgroundColor: Ct.leaf,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go("/lots/${m["lot_id"] ?? ""}");
      }
    } on ApiException catch (e) {
      setState(() => _error = _friendly(e));
    } catch (_) {
      setState(() => _error = "Could not create the export. Try again.");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _friendly(ApiException e) {
    switch (e.code) {
      case "LOT_NO_TAKEN":
        return "Lot number already used — pull to refresh and try again (the number auto-increments).";
      case "LOT_CANDIDATES_INVALID":
        return "One of the selected batches can no longer be exported. Refresh and retry.";
      case "NETWORK" || "TIMEOUT":
        return "No internet connection. Try again.";
      default:
        return "Could not create the export. Try again.";
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final batchesAsync = ref.watch(batchesProvider);
    final lotsAsync = ref.watch(myLotsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Ct.ink),
          onPressed: () => ctNavigateBack(context, fallback: "/home"),
        ),
        title: Text("New export lot", style: text.titleLarge),
      ),
      body: SafeArea(
        child: batchesAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: Ct.cinnamon)),
          error: (err, stack) => Center(
            child: Text("Could not load batches", style: text.bodyMedium),
          ),
          data: (batches) {
            // Exportable = currently held by me, in an exportable status.
            final auth = ref.watch(authProvider);
            final myId = auth is SignedIn ? auth.user.id : null;
            final candidates = batches
                .where((b) =>
                    b["current_holder_id"]?.toString() == myId &&
                    _exportableStatuses.contains(b["status"].toString()))
                .toList();
            // Cache the lots list outside build (read by _nextLotNo); no
            // setState here — build must stay side-effect free.
            _lotsThisYear = lotsAsync.asData?.value;

            if (candidates.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(Ct.pad),
                children: [
                  CtCard(
                    child: Column(
                      children: [
                        const Icon(Icons.inventory_2_outlined,
                            size: 40, color: Ct.faded),
                        const SizedBox(height: 10),
                        Text(
                          "No batches ready to export",
                          style: text.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Batches you have received (or processed) can be merged into a container lot here.",
                          style: text.bodyMedium?.copyWith(color: Ct.faded),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final totalWeight = candidates
                .where((b) => _selected.contains(b["id"].toString()))
                .fold<double>(0, (s, b) => s + ((b["weight_kg"] as num?)?.toDouble() ?? 0));

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(Ct.pad),
                    children: [
                      Text("Select batches to merge", style: text.titleMedium),
                      const SizedBox(height: 8),
                      for (final b in candidates)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: CtCard(
                            child: CheckboxListTile(
                              value: _selected.contains(b["id"].toString()),
                              onChanged: (on) => setState(() {
                                if (on == true) {
                                  _selected.add(b["id"].toString());
                                } else {
                                  _selected.remove(b["id"].toString());
                                }
                              }),
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: Ct.leaf,
                              title: Text(
                                b["batch_no"].toString(),
                                style: text.titleMedium?.copyWith(fontFamily: Ct.display),
                              ),
                              subtitle: Text(
                                "${b["weight_kg"]} kg · ${b["status"]}",
                                style: text.bodyMedium?.copyWith(color: Ct.faded),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      CtCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Shipment", style: text.titleMedium),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _buyerCtrl,
                              decoration: const InputDecoration(
                                labelText: "Buyer (optional)",
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _containerCtrl,
                              decoration: const InputDecoration(
                                labelText: "Container no (optional)",
                                hintText: "MSKU1234567",
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.event, size: 20, color: Ct.faded),
                                const SizedBox(width: 10),
                                Text("Ship date: ${fmtDate(_shipmentDate.toIso8601String())}",
                                    style: text.bodyMedium),
                                const Spacer(),
                                TextButton(
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _shipmentDate,
                                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                      lastDate: DateTime.now().add(const Duration(days: 180)),
                                    );
                                    if (picked != null) {
                                      setState(() => _shipmentDate = picked);
                                    }
                                  },
                                  child: const Text("Change"),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Ct.pad, 0, Ct.pad, 6),
                    child: CtCard(
                      color: Ct.quillSoft,
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Ct.cinnamon),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_error!, style: text.bodyMedium)),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(Ct.pad),
                  child: CtButton(
                    label: _selected.isEmpty
                        ? "Export lot"
                        : "Export lot · ${_selected.length} batch(es) · $totalWeight kg",
                    icon: Icons.local_shipping,
                    loading: _sending,
                    onPressed: _sending ? null : _export,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

const _exportableStatuses = {"HARVESTED", "RECEIVED", "PROCESSED"};

/// `EX-001-2026-EXP-A` → group 1 = year, group 2 = sequence.
final lotNoSeqPattern = RegExp(r"^EX-(\d{3})-(\d{4})-EXP-");
