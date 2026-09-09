import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../app/theme.dart";
import "../../core/api/api_exception.dart";
import "../../core/auth/auth_state.dart";
import "../../core/data/repositories.dart";
import "../../core/widgets/ct_widgets.dart";

/// Processing screen for P1 / P2 (api-spec §5).
///
/// P1: number is forced to `…/P1` — no rename field is shown at all.
/// P2: number gets `…/P2` by default, or the processor may supply a custom
/// number (`AA-JJJ-SS-YYYY-P2-CODE`). The origin link is server-side and
/// never breaks: old numbers stay resolvable (aliases), root never changes.
class ProcessScreen extends ConsumerStatefulWidget {
  const ProcessScreen({super.key, required this.batchId});

  final String batchId;

  @override
  ConsumerState<ProcessScreen> createState() => _ProcessScreenState();
}

class _ProcessScreenState extends ConsumerState<ProcessScreen> {
  final _weightCtrl = TextEditingController();
  final _customNoCtrl = TextEditingController();
  bool _sending = false;
  String? _error;
  String? _suggestedNo;
  String? _stage; // P1 | P2
  String? _currentNo;

  @override
  void initState() {
    super.initState();
    _loadSuggestion();
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _customNoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestion() async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get("/batches/${widget.batchId}/process/suggest");
      final m = Map<String, dynamic>.from(data as Map);
      if (!mounted) return;
      setState(() {
        _stage = m["stage"]?.toString();
        _suggestedNo = m["suggested_batch_no"]?.toString();
      });
    } catch (_) {
      // Suggestion is a nicety; the process POST computes the same server-side.
    }
  }

  Future<void> _submit() async {
    final weight = double.tryParse(_weightCtrl.text.trim());
    if (weight == null || weight <= 0) {
      setState(() => _error = "Enter the output weight in kg");
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final custom = _customNoCtrl.text.trim();
      final body = <String, dynamic>{
        "output_weight_kg": weight,
        if (_stage == "P2" && custom.isNotEmpty) "batch_no": custom.toUpperCase(),
      };
      final data = await api.post("/batches/${widget.batchId}/process", body: body);
      final m = Map<String, dynamic>.from(data as Map);
      // Immediate local update so the UI reflects the new number/status
      // without waiting for the next pull.
      await ref.read(batchesRepoProvider).updateBatchLocalProcess(
            batchId: widget.batchId,
            batchNo: m["batch_no"]?.toString(),
            stageSuffix: m["stage_suffix"]?.toString(),
            weightKg: weight,
          );
      ref.invalidate(batchesProvider);
      ref.invalidate(batchByIdProvider(widget.batchId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              m["previous_batch_no"] != null
                  ? "Processed — renumbered to ${m["batch_no"]}"
                  : "Processed — number ${m["batch_no"]}",
            ),
            backgroundColor: Ct.leaf,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go("/batch/${widget.batchId}");
      }
    } on ApiException catch (e) {
      setState(() => _error = _friendly(e));
    } catch (_) {
      setState(() => _error = "Could not save processing. Try again.");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _friendly(ApiException e) {
    switch (e.code) {
      case "P1_NOT_RENAMABLE":
        return "P1 numbers are automatic — only P2 can rename.";
      case "BATCH_NO_TAKEN":
        return "That number is already used. Pick another.";
      case "NOT_PROCESSABLE":
        return "Accept the batch before processing it.";
      case "NOT_HOLDER":
        return "You don't hold this batch anymore.";
      case "NETWORK" || "TIMEOUT":
        return "No internet connection. Try again.";
      default:
        return "Could not save processing. Try again.";
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final batchAsync = ref.watch(batchByIdProvider(widget.batchId));
    final isP2 = _stage == "P2";

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Ct.ink),
          onPressed: () => ctNavigateBack(context, fallback: "/batches"),
        ),
        title: Text("Record processing", style: text.titleLarge),
      ),
      body: SafeArea(
        child: batchAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: Ct.cinnamon)),
          error: (err, stack) => Center(
            child: Text("Could not load batch", style: text.bodyMedium),
          ),
          data: (b) {
            _currentNo = b["batch_no"]?.toString();
            final batchNo = _currentNo ?? "";
            return ListView(
              padding: const EdgeInsets.all(Ct.pad),
              children: [
                CtCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(batchNo, style: text.headlineMedium?.copyWith(fontFamily: Ct.display, color: Ct.cinnamon)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          StatusChip(label: "${b["weight_kg"]} kg in", color: Ct.quill),
                          StatusChip(
                            label: isP2 ? "Stage P2 · grinding" : "Stage P1 · peeling/quilling",
                            color: Ct.cinnamon,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                CtCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Output weight (kg)", style: text.titleMedium),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _weightCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: "e.g. 45.5",
                          border: const OutlineInputBorder(),
                          errorText: _error != null && _error!.contains("weight") ? _error : null,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (isP2) ...[
                        Text("Batch number", style: text.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          "Keep the automatic number, or set your own. The link to the origin batch is always kept either way.",
                          style: text.bodyMedium?.copyWith(color: Ct.faded),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _customNoCtrl,
                          decoration: InputDecoration(
                            hintText: _suggestedNo ?? "…/P2",
                            helperText: "Leave empty to use the automatic number",
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            const Icon(Icons.lock_outline, size: 18, color: Ct.faded),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _suggestedNo == null
                                    ? "Number is automatic for this stage."
                                    : "Number becomes $_suggestedNo — automatic for this stage.",
                                style: text.bodyMedium?.copyWith(color: Ct.faded),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (_error != null && !_error!.contains("weight")) ...[
                  const SizedBox(height: 12),
                  CtCard(
                    color: Ct.quillSoft,
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Ct.cinnamon),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_error!, style: text.bodyMedium)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                CtButton(
                  label: "Save processing",
                  icon: Icons.precision_manufacturing,
                  loading: _sending,
                  onPressed: _sending ? null : _submit,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
