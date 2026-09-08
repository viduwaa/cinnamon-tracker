import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../app/theme.dart";
import "../../core/auth/auth_state.dart";
import "../../core/data/repositories.dart";
import "../../core/domain/batch_number_generator.dart";
import "../../core/sync/sync_worker.dart";
import "../../core/widgets/ct_widgets.dart";

/// Draft state for the harvest wizard.
class HarvestDraft {
  HarvestDraft({
    this.farmId,
    this.farmName,
    this.areaCode,
    this.farmerCode,
    this.date,
    this.type,
    this.treeCount,
    this.weightKg,
  });

  String? farmId;
  String? farmName;
  String? areaCode;
  String? farmerCode;
  DateTime? date;
  HarvestType? type;
  int? treeCount;
  double? weightKg;
}

class HarvestWizardScreen extends ConsumerStatefulWidget {
  const HarvestWizardScreen({super.key});

  @override
  ConsumerState<HarvestWizardScreen> createState() => _HarvestWizardScreenState();
}

class _HarvestWizardScreenState extends ConsumerState<HarvestWizardScreen> {
  final _draft = HarvestDraft();
  int _step = 0;
  bool _saving = false;
  String? _error;

  final _treeCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  @override
  void dispose() {
    _treeCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  String get _previewNo {
    if (_draft.areaCode == null ||
        _draft.date == null ||
        _draft.farmerCode == null ||
        _draft.type == null) {
      return "…";
    }
    try {
      return generateBatchNo(
        areaCode: _draft.areaCode!,
        harvestDate: _draft.date!,
        seq: 1, // preview only; real seq allocated on save
        farmerCode: _draft.farmerCode!,
        type: _draft.type!,
      );
    } catch (_) {
      return "…";
    }
  }

  bool get _canNext => switch (_step) {
        0 => _draft.farmId != null,
        1 => _draft.date != null,
        2 => _draft.type != null,
        3 => (_draft.treeCount ?? 0) >= 1 && (_draft.weightKg ?? 0) > 0,
        _ => true,
      };

  /// Local-first save (flutter-plan §4.4): one drift transaction allocates
  /// the daily sequence, generates the batch number, stores the row and
  /// queues the outbox entry. The sync worker pushes it when online.
  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider);
      if (auth is! SignedIn) {
        throw StateError("SIGNED_OUT");
      }
      final id = await ref.read(batchesRepoProvider).saveHarvest(
            farmId: _draft.farmId!,
            holderId: auth.user.id,
            harvestDate: _draft.date!,
            type: _draft.type!,
            treeCount: _draft.treeCount ?? 0,
            weightKg: _draft.weightKg ?? 0,
          );
      // Push immediately when online; harmless no-op queueing when not.
      unawaited(ref.read(syncWorkerProvider).drain());
      if (mounted) context.go("/harvest/done/$id");
    } catch (e) {
      setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains("FARM_NOT_ACTIVATED") ||
        s.contains("FARM_NOT_FOUND")) {
      return "This farm is still syncing. Please try again in a moment.";
    }
    if (s.contains("SEQ_EXHAUSTED")) {
      return "Daily harvest limit reached for this farm.";
    }
    if (s.contains("SIGNED_OUT")) return "Please sign in again.";
    if (s.contains("NETWORK") || s.contains("TIMEOUT")) {
      // Should not happen — saves are local — but stay friendly anyway.
      return "Saved on this phone. It will sync when you're online.";
    }
    return "Could not save. Please try again.";
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, color: Ct.ink),
          onPressed: () => ctNavigateBack(context, fallback: "/home"),
        ),
        title: Text("New Harvest", style: text.titleLarge),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _StepDots(step: _step, total: 5),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Ct.pad),
                child: _buildStep(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Ct.pad),
              child: Column(
                children: [
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: text.bodyMedium?.copyWith(color: Ct.clay),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                  ],
                  CtButton(
                    label: _step == 4 ? "Confirm Harvest" : "Next",
                    icon: _step == 4 ? Icons.check_circle_outline : Icons.arrow_forward,
                    loading: _saving,
                    enabled: _canNext,
                    onPressed: () {
                      if (_step == 4) {
                        _save();
                      } else {
                        setState(() => _step++);
                      }
                    },
                  ),
                  if (_step > 0) ...[
                    const SizedBox(height: 10),
                    CtButton(
                      label: "Back",
                      secondary: true,
                      onPressed: () => setState(() => _step--),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _FarmStep(
          selected: _draft.farmId,
          onPick: (farm) => setState(() {
            _draft.farmId = farm["id"].toString();
            _draft.farmName = farm["name"].toString();
            _draft.areaCode = farm["area_code"].toString();
            _draft.farmerCode = farm["farmer_code"].toString();
          }),
        );
      case 1:
        return _DateStep(
          selected: _draft.date,
          onPick: (d) => setState(() => _draft.date = d),
        );
      case 2:
        return _TypeStep(
          selected: _draft.type,
          onPick: (t) => setState(() => _draft.type = t),
        );
      case 3:
        return _NumbersStep(
          treeCtrl: _treeCtrl,
          weightCtrl: _weightCtrl,
          onTree: (v) => setState(() => _draft.treeCount = int.tryParse(v)),
          onWeight: (v) => setState(() => _draft.weightKg = double.tryParse(v)),
        );
      default:
        return _ReviewStep(draft: _draft, previewNo: _previewNo);
    }
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.step, required this.total});
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total, (i) {
          final active = i <= step;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: active ? 26 : 10,
            height: 10,
            decoration: BoxDecoration(
              color: active ? Ct.cinnamon : Ct.line,
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }
}

class _FarmStep extends ConsumerWidget {
  const _FarmStep({required this.selected, required this.onPick});
  final String? selected;
  final ValueChanged<Map<String, dynamic>> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farms = ref.watch(farmsProvider);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Which farm?", style: text.headlineMedium),
        const SizedBox(height: 18),
        farms.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Text("Could not load farms", style: text.bodyMedium),
          data: (list) => list.isEmpty
              ? CtCard(
                  color: Ct.leafSoft,
                  child: Column(
                    children: [
                      Text("Add a farm first", style: text.titleMedium),
                      const SizedBox(height: 12),
                      CtButton(
                        label: "Add Farm",
                        icon: Icons.add,
                        onPressed: () => context.push("/farm/new"),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (final f in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: CtCard(
                          onTap: () => onPick(f),
                          color: f["id"] == selected ? Ct.leafSoft : Ct.paper,
                          child: Row(
                            children: [
                              Icon(
                                f["id"] == selected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: f["id"] == selected ? Ct.leaf : Ct.faded,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(f["name"].toString(), style: text.titleMedium),
                                    Text(
                                      "${f["size_value"]} ${f["size_unit"]} · ${f["area_code"]}",
                                      style: text.bodyMedium?.copyWith(color: Ct.faded),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _DateStep extends StatelessWidget {
  const _DateStep({required this.selected, required this.onPick});
  final DateTime? selected;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final today = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Harvest date", style: text.headlineMedium),
        const SizedBox(height: 18),
        CtCard(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selected ?? today,
              firstDate: DateTime(2020),
              lastDate: today,
            );
            if (picked != null) onPick(picked);
          },
          child: Row(
            children: [
              const Icon(Icons.calendar_month, color: Ct.cinnamon, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  selected == null
                      ? "Tap to choose a date"
                      : "${selected!.day}/${selected!.month}/${selected!.year}",
                  style: text.titleLarge,
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Ct.faded),
            ],
          ),
        ),
        const SizedBox(height: 14),
        CtButton(
          label: "Today",
          secondary: true,
          icon: Icons.today,
          onPressed: () => onPick(today),
        ),
      ],
    );
  }
}

class _TypeStep extends StatelessWidget {
  const _TypeStep({required this.selected, required this.onPick});
  final HarvestType? selected;
  final ValueChanged<HarvestType> onPick;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("How was it harvested?", style: text.headlineMedium),
        const SizedBox(height: 18),
        _TypeCard(
          icon: Icons.park_outlined,
          title: "Trees",
          subtitle: "Whole branches cut (T)",
          selected: selected == HarvestType.trees,
          onTap: () => onPick(HarvestType.trees),
        ),
        const SizedBox(height: 14),
        _TypeCard(
          icon: Icons.grain_outlined,
          title: "Quills",
          subtitle: "Rolled quills ready (Q)",
          selected: selected == HarvestType.quills,
          onTap: () => onPick(HarvestType.quills),
        ),
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return CtCard(
      onTap: onTap,
      color: selected ? Ct.quillSoft : Ct.paper,
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: selected ? Ct.quill : Ct.cream,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 36, color: selected ? Ct.paper : Ct.cinnamon),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleLarge),
                const SizedBox(height: 2),
                Text(subtitle, style: text.bodyMedium?.copyWith(color: Ct.faded)),
              ],
            ),
          ),
          if (selected) const Icon(Icons.check_circle, color: Ct.quill, size: 28),
        ],
      ),
    );
  }
}

class _NumbersStep extends StatelessWidget {
  const _NumbersStep({
    required this.treeCtrl,
    required this.weightCtrl,
    required this.onTree,
    required this.onWeight,
  });

  final TextEditingController treeCtrl;
  final TextEditingController weightCtrl;
  final ValueChanged<String> onTree;
  final ValueChanged<String> onWeight;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("How much?", style: text.headlineMedium),
        const SizedBox(height: 18),
        CtField(
          label: "Tree count",
          controller: treeCtrl,
          keyboardType: TextInputType.number,
          hint: "45",
          prefix: const Icon(Icons.park_outlined, color: Ct.faded),
          onChanged: onTree,
        ),
        const SizedBox(height: 18),
        CtField(
          label: "Weight (kg)",
          controller: weightCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          hint: "120.5",
          prefix: const Icon(Icons.monitor_weight_outlined, color: Ct.faded),
          onChanged: onWeight,
        ),
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.draft, required this.previewNo});
  final HarvestDraft draft;
  final String previewNo;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Confirm", style: text.headlineMedium),
        const SizedBox(height: 18),
        CtCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Row(label: "Farm", value: draft.farmName ?? "—"),
              _Row(
                label: "Date",
                value: draft.date == null
                    ? "—"
                    : "${draft.date!.day}/${draft.date!.month}/${draft.date!.year}",
              ),
              _Row(
                label: "Type",
                value: draft.type == HarvestType.trees ? "Trees (T)" : "Quills (Q)",
              ),
              _Row(label: "Trees", value: "${draft.treeCount ?? 0}"),
              _Row(label: "Weight", value: "${draft.weightKg ?? 0} kg"),
              const Divider(height: 24),
              Text("Batch number will be", style: text.labelMedium),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Ct.quillSoft,
                  borderRadius: BorderRadius.circular(Ct.radiusSm),
                ),
                child: Text(
                  previewNo,
                  textAlign: TextAlign.center,
                  style: text.titleLarge?.copyWith(
                    fontFamily: Ct.display,
                    color: Ct.cinnamon,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: text.labelMedium),
          ),
          Expanded(
            child: Text(value, style: text.bodyLarge),
          ),
        ],
      ),
    );
  }
}
