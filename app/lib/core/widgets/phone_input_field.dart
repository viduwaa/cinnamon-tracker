import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "../../app/theme.dart";

/// Country code descriptor for phone input.
class CountryCode {
  const CountryCode({
    required this.dialCode,
    required this.name,
    required this.flag,
    this.example = "771234567",
  });

  final String dialCode;
  final String name;
  final String flag;
  final String example;
}

const List<CountryCode> supportedCountryCodes = [
  CountryCode(dialCode: "+94", name: "Sri Lanka", flag: "🇱🇰", example: "077 123 4567"),
  CountryCode(dialCode: "+1", name: "USA / Canada", flag: "🇺🇸", example: "(202) 555-0123"),
  CountryCode(dialCode: "+44", name: "United Kingdom", flag: "🇬🇧", example: "7911 123456"),
  CountryCode(dialCode: "+91", name: "India", flag: "🇮🇳", example: "98765 43210"),
  CountryCode(dialCode: "+61", name: "Australia", flag: "🇦🇺", example: "412 345 678"),
  CountryCode(dialCode: "+971", name: "UAE", flag: "🇦🇪", example: "50 123 4567"),
  CountryCode(dialCode: "+65", name: "Singapore", flag: "🇸🇬", example: "8123 4567"),
  CountryCode(dialCode: "+49", name: "Germany", flag: "🇩🇪", example: "151 1234567"),
  CountryCode(dialCode: "+33", name: "France", flag: "🇫🇷", example: "6 12 34 56 78"),
  CountryCode(dialCode: "+81", name: "Japan", flag: "🇯🇵", example: "90 1234 5678"),
  CountryCode(dialCode: "+86", name: "China", flag: "🇨🇳", example: "138 0013 8000"),
  CountryCode(dialCode: "+39", name: "Italy", flag: "🇮🇹", example: "312 345 6789"),
  CountryCode(dialCode: "+31", name: "Netherlands", flag: "🇳🇱", example: "6 12345678"),
  CountryCode(dialCode: "+41", name: "Switzerland", flag: "🇨🇭", example: "78 123 45 67"),
  CountryCode(dialCode: "+60", name: "Malaysia", flag: "🇲🇾", example: "12 345 6789"),
  CountryCode(dialCode: "+960", name: "Maldives", flag: "🇲🇻", example: "771 2345"),
  CountryCode(dialCode: "+974", name: "Qatar", flag: "🇶🇦", example: "3312 3456"),
  CountryCode(dialCode: "+966", name: "Saudi Arabia", flag: "🇸🇦", example: "50 123 4567"),
  CountryCode(dialCode: "+968", name: "Oman", flag: "🇴🇲", example: "9123 4567"),
  CountryCode(dialCode: "+965", name: "Kuwait", flag: "🇰🇼", example: "5123 4567"),
  CountryCode(dialCode: "+973", name: "Bahrain", flag: "🇧🇭", example: "3600 1234"),
];

/// Normalizes any raw phone input string + country code into canonical E.164 (+...).
String normalizePhoneNumber(String rawNumber, {String defaultDialCode = "+94"}) {
  if (rawNumber.trim().isEmpty) return "";
  var digits = rawNumber.trim().replaceAll(RegExp(r"[\s\-().]"), "");

  if (digits.startsWith("00")) {
    digits = "+${digits.substring(2)}";
  }

  if (digits.startsWith("+")) {
    return digits;
  }

  if (digits.startsWith("94") && digits.length == 11) {
    return "+$digits";
  }

  if (digits.startsWith("0")) {
    final code = defaultDialCode.startsWith("+") ? defaultDialCode : "+$defaultDialCode";
    return "$code${digits.substring(1)}";
  }

  if (defaultDialCode == "+94" && digits.length == 9 && digits.startsWith("7")) {
    return "+94$digits";
  }

  final code = defaultDialCode.startsWith("+") ? defaultDialCode : "+$defaultDialCode";
  return "$code$digits";
}

/// Phone input widget with integrated Country Code selector.
class PhoneInputField extends StatefulWidget {
  const PhoneInputField({
    super.key,
    required this.controller,
    this.initialDialCode = "+94",
    this.onChanged,
    this.label = "Mobile number",
    this.enabled = true,
  });

  final TextEditingController controller;
  final String initialDialCode;
  final ValueChanged<String>? onChanged;
  final String label;
  final bool enabled;

  @override
  State<PhoneInputField> createState() => _PhoneInputFieldState();
}

class _PhoneInputFieldState extends State<PhoneInputField> {
  late CountryCode _selectedCountry;

  @override
  void initState() {
    super.initState();
    _selectedCountry = supportedCountryCodes.firstWhere(
      (c) => c.dialCode == widget.initialDialCode,
      orElse: () => supportedCountryCodes.first,
    );
  }

  void _onTextChanged(String text) {
    // If the user pastes an international number starting with + or 00, auto-detect country code
    var raw = text.trim();
    if (raw.startsWith("+")) {
      for (final c in supportedCountryCodes) {
        if (raw.startsWith(c.dialCode) && c.dialCode != "+1") {
          setState(() {
            _selectedCountry = c;
          });
          break;
        }
      }
    }
    final normalized = normalizePhoneNumber(widget.controller.text, defaultDialCode: _selectedCountry.dialCode);
    widget.onChanged?.call(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: textTheme.labelMedium),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: widget.enabled ? Ct.paper : Ct.cream,
            borderRadius: BorderRadius.circular(Ct.radiusSm),
            border: Border.all(color: Ct.line),
          ),
          child: Row(
            children: [
              // Country Code Selector Button
              InkWell(
                onTap: widget.enabled ? () => _showCountryPicker(context) : null,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(Ct.radiusSm)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: Ct.line)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedCountry.flag,
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _selectedCountry.dialCode,
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Ct.ink,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, size: 20, color: Ct.faded),
                    ],
                  ),
                ),
              ),
              // National Number Text Field
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r"[0-9\s\-()]")),
                  ],
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  decoration: InputDecoration(
                    hintText: _selectedCountry.example,
                    hintStyle: textTheme.bodyMedium?.copyWith(color: Ct.faded),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                  onChanged: _onTextChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCountryPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Ct.radius)),
      ),
      backgroundColor: Ct.paper,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.85,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(Ct.pad),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Ct.line,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Select Country Code",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: supportedCountryCodes.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, indent: 64),
                    itemBuilder: (context, index) {
                      final country = supportedCountryCodes[index];
                      final isSelected = country.dialCode == _selectedCountry.dialCode;
                      return ListTile(
                        leading: Text(country.flag, style: const TextStyle(fontSize: 26)),
                        title: Text(country.name, style: Theme.of(context).textTheme.titleMedium),
                        trailing: Text(
                          country.dialCode,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Ct.cinnamon : Ct.faded,
                              ),
                        ),
                        selected: isSelected,
                        selectedTileColor: Ct.quillSoft,
                        onTap: () {
                          setState(() {
                            _selectedCountry = country;
                          });
                          Navigator.pop(context);
                          _onTextChanged(widget.controller.text);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
