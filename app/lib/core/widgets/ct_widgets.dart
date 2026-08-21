import "package:flutter/material.dart";
import "../../app/theme.dart";

/// Format an ISO date/datetime string as a friendly dd/mm/yyyy.
String fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return "";
  final d = DateTime.tryParse(iso);
  if (d == null) return iso.length >= 10 ? iso.substring(0, 10) : iso;
  final local = d.toLocal();
  return "${local.day.toString().padLeft(2, "0")}/${local.month.toString().padLeft(2, "0")}/${local.year}";
}

/// Primary action button — large, rounded, high-contrast.
class CtButton extends StatelessWidget {
  const CtButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.secondary = false,
    this.loading = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;
  final bool loading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 22),
                const SizedBox(width: 10),
              ],
              Flexible(child: Text(label, textAlign: TextAlign.center)),
            ],
          );

    if (secondary) {
      return OutlinedButton(
        onPressed: enabled && !loading ? onPressed : null,
        child: child,
      );
    }
    return ElevatedButton(
      onPressed: enabled && !loading ? onPressed : null,
      child: child,
    );
  }
}

/// Soft card on the cream background.
class CtCard extends StatelessWidget {
  const CtCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Ct.pad),
    this.color = Ct.paper,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(Ct.radius),
        border: Border.all(color: Ct.line, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x144A2C17),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Ct.radius),
        child: card,
      ),
    );
  }
}

/// Labeled text field with a big touch target.
class CtField extends StatelessWidget {
  const CtField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.keyboardType,
    this.prefix,
    this.suffix,
    this.errorText,
    this.obscure = false,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final TextInputType? keyboardType;
  final Widget? prefix;
  final Widget? suffix;
  final String? errorText;
  final bool obscure;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscure,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          autofocus: autofocus,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefix,
            suffixIcon: suffix,
            errorText: errorText,
          ),
        ),
      ],
    );
  }
}

/// Small rounded status chip.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: Ct.body,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Thin banner shown when the device is offline.
class OfflineBanner extends StatelessWidget {  const OfflineBanner({super.key, this.visible = true});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Ct.pad, vertical: 10),
      color: Ct.quill,
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 18, color: Ct.bark),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "No internet — saved on this phone, will sync",
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Ct.bark, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
