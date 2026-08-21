import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../app/theme.dart";
import "../../core/auth/auth_state.dart";
import "../../core/widgets/ct_widgets.dart";
import "../home/home_screen.dart";

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
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  String? _areaCode;
  String _unit = "ACRE";
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sizeCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
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
      final api = ref.read(apiClientProvider);
      await api.post("/farms", body: {
        "id": _uuidv7(),
        "name": _nameCtrl.text.trim(),
        "area_code": _areaCode,
        "size_value": size,
        "size_unit": _unit,
        "lat": double.tryParse(_latCtrl.text),
        "lng": double.tryParse(_lngCtrl.text),
        "address_text":
            _addrCtrl.text.trim().isEmpty ? null : _addrCtrl.text.trim(),
      });
      ref.invalidate(farmsProvider);
      if (mounted) context.go("/home");
    } catch (e) {
      setState(() => _error = "Could not save. Check your connection.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _uuidv7() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rand = List<int>.generate(10, (_) => DateTime.now().microsecond % 256);
    final b = <int>[
      (now >> 40) & 0xff, (now >> 32) & 0xff, (now >> 24) & 0xff,
      (now >> 16) & 0xff, (now >> 8) & 0xff, now & 0xff,
      ...rand,
    ];
    b[6] = (b[6] & 0x0f) | 0x70;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, "0")).join();
    return "${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}";
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, color: Ct.ink),
          onPressed: () => context.go("/home"),
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
              Text("Location (optional)", style: text.labelMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: CtField(
                      label: "Latitude",
                      controller: _latCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      hint: "6.0329",
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CtField(
                      label: "Longitude",
                      controller: _lngCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      hint: "80.2168",
                    ),
                  ),
                ],
              ),
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
