import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../app/theme.dart";
import "../../core/api/maps_api_key.dart";
import "../../core/data/repositories.dart";
import "../../core/sync/sync_worker.dart";
import "../../core/widgets/ct_widgets.dart";
import "farm_location_picker.dart";

/// Sri Lankan districts → 2-letter area codes (bundled lookup).
const _districts = [
  ("GM", "Galle", "ගාල්ල"),
  ("MA", "Matara", "මාතර"),
  ("HB", "Hambantota", "හම්බන්තොට"),
  ("KN", "Kandy", "මහනුවර"),
  ("ML", "Matale", "මාතලේ"),
  ("NU", "Nuwara Eliya", "නුවරඑළිය"),
  ("CO", "Colombo", "කොළඹ"),
  ("GA", "Gampaha", "ගම්පහ"),
  ("KL", "Kalutara", "කළුතර"),
  ("KM", "Kurunegala", "කුරුණෑගල"),
  ("PU", "Puttalam", "පුත්තලම"),
  ("AN", "Anuradhapura", "අනුරාධපුරය"),
  ("PO", "Polonnaruwa", "පොළොන්නරුව"),
  ("BD", "Badulla", "බදුල්ල"),
  ("MO", "Monaragala", "මොණරාගල"),
  ("RA", "Ratnapura", "රත්නපුරය"),
  ("KE", "Kegalle", "කෑගල්ල"),
  ("BT", "Batticaloa", "මඩකලපුව"),
  ("AM", "Ampara", "අම්පාර"),
  ("TR", "Trincomalee", "ත්‍රිකුණාමලය"),
  ("JA", "Jaffna", "යාපනය"),
  ("KI", "Kilinochchi", "කිලිනොච්චිය"),
  ("MN", "Mannar", "මන්නාරම"),
  ("VA", "Vavuniya", "වව්නියාව"),
  ("MU", "Mullaitivu", "මුලතිව්"),
];

class FarmWizardScreen extends ConsumerStatefulWidget {
  const FarmWizardScreen({super.key});

  @override
  ConsumerState<FarmWizardScreen> createState() => _FarmWizardScreenState();
}

class _FarmWizardScreenState extends ConsumerState<FarmWizardScreen> {
  final _nameCtrl = TextEditingController();
  final _sizeCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  double? _lat;
  double? _lng;
  String _publicLevel = "EXACT";
  String? _areaCode;
  String _unit = "ACRE";
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sizeCtrl.dispose();
    _addrCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().length < 2) {
      setState(() => _error = "Please enter a farm name");
      return;
    }
    if (_areaCode == null) {
      setState(() => _error = "Please select your district");
      return;
    }
    final size = double.tryParse(_sizeCtrl.text);
    if (size == null || size <= 0) {
      setState(() => _error = "Please enter the land size");
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Offline-first: the farm row is stored locally (syncState LOCAL) and
      // queued in the outbox; the SyncWorker pushes it when online.
      await ref.read(farmsRepoProvider).saveFarmDraft(
            name: _nameCtrl.text.trim(),
            areaCode: _areaCode!,
            sizeValue: size,
            sizeUnit: _unit,
            lat: _lat,
            lng: _lng,
            addressText:
                _addrCtrl.text.trim().isEmpty ? null : _addrCtrl.text.trim(),
            // Only meaningful when the farmer pinned a location on the map;
            // DISTRICT otherwise (server gates coordinates on this).
            locationPublicLevel:
                _lat != null && _lng != null ? _publicLevel : "DISTRICT",
          );
      // Kick the drain so an online device syncs immediately.
      unawaited(ref.read(syncWorkerProvider).drain());
      if (mounted) context.go("/home");
    } catch (_) {
      setState(() => _error = "Could not save. Please try again.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
        title: Text("Add Farm", style: text.titleLarge),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Ct.pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Tell us about your farm", style: text.headlineMedium),
              const SizedBox(height: 22),
              CtField(
                label: "Farm name",
                controller: _nameCtrl,
                hint: "Home Garden",
                prefix: const Icon(Icons.yard_outlined, color: Ct.faded),
              ),
              const SizedBox(height: 18),
              Text("District", style: text.labelMedium),
              const SizedBox(height: 8),
              CtCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _areaCode,
                    isExpanded: true,
                    hint: Text("Select district",
                        style: text.bodyMedium?.copyWith(color: Ct.faded)),
                    items: [
                      for (final d in _districts)
                        DropdownMenuItem(
                          value: d.$1,
                          child: Text("${d.$2} · ${d.$3}"),
                        ),
                    ],
                    onChanged: (v) => setState(() => _areaCode = v),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: CtField(
                      label: "Land size",
                      controller: _sizeCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      hint: "1.5",
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Unit", style: text.labelMedium),
                        const SizedBox(height: 8),
                        CtCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 2),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _unit,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(value: "ACRE", child: Text("Acres")),
                                DropdownMenuItem(value: "PERCH", child: Text("Perches")),
                                DropdownMenuItem(value: "HECTARE", child: Text("Hectares")),
                              ],
                              onChanged: (v) =>
                                  setState(() => _unit = v ?? "ACRE"),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (kMapsEnabled) ...[
                FarmLocationPicker(
                  lat: _lat,
                  lng: _lng,
                  onChanged: (v) => setState(() {
                    _lat = v.$1;
                    _lng = v.$2;
                  }),
                ),
              ] else ...[
                Text("Location (optional)", style: text.labelMedium),
                const SizedBox(height: 8),
                CtCard(
                  child: Row(
                    children: [
                      const Icon(Icons.map_outlined, color: Ct.faded),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Map picker is disabled — the app was built "
                          "without a Google Maps key.",
                          style: text.bodyMedium?.copyWith(color: Ct.faded),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Privacy of the pinned location — asked only when a pin
              // exists; DISTRICT farms have nothing to expose.
              if (_lat != null && _lng != null) ...[
                const SizedBox(height: 18),
                Text("Who sees the exact farm pin?", style: text.labelMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final (value, label, icon) in const [
                      ("EXACT", "Everyone", Icons.public),
                      ("HIDDEN", "Only me", Icons.lock_outline),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 16, color: Ct.cinnamon),
                              const SizedBox(width: 6),
                              Text(label),
                            ],
                          ),
                          selected: _publicLevel == value,
                          onSelected: (_) =>
                              setState(() => _publicLevel = value),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _publicLevel == "EXACT"
                      ? "Buyers and verifiers see the exact pin on the map — strongest authenticity proof."
                      : "The pin stays private; verification shows the district only.",
                  style: text.bodySmall?.copyWith(color: Ct.faded),
                ),
              ],
              const SizedBox(height: 18),
              CtField(
                label: "Address (optional)",
                controller: _addrCtrl,
                hint: "Walpita, Galle",
                prefix: const Icon(Icons.place_outlined, color: Ct.faded),
              ),
              if (_error != null) ...[
                const SizedBox(height: 18),
                Text(_error!,
                    style: text.bodyMedium?.copyWith(color: Ct.clay)),
              ],
              const SizedBox(height: 26),
              CtButton(
                label: "Save Farm",
                icon: Icons.check_circle_outline,
                loading: _saving,
                onPressed: _save,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
