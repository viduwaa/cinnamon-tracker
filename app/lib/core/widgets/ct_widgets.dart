import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:go_router/go_router.dart";
import "../../app/theme.dart";

/// Format an ISO date/datetime string as a friendly dd/mm/yyyy.
String fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return "";
  final d = DateTime.tryParse(iso);
  if (d == null) return iso.length >= 10 ? iso.substring(0, 10) : iso;
  final local = d.toLocal();
  return "${local.day.toString().padLeft(2, "0")}/${local.month.toString().padLeft(2, "0")}/${local.year}";
}

/// Human label for a role code — shared by every screen that shows custody.
String ctRoleLabel(String role) => switch (role) {
      "FARMER" => "Farmer",
      "PROCESSOR_L1" => "Processor L1",
      "COLLECTOR" => "Collector",
      "PROCESSOR_L2" => "Processor L2",
      "EXPORTER" => "Exporter",
      _ => role,
    };

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

/// Safely navigates back if possible, otherwise navigates to the fallback route.
void ctNavigateBack(BuildContext context, {String fallback = "/home"}) {
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  } else {
    // ignore: use_build_context_synchronously
    GoRouter.of(context).go(fallback);
  }
}

/// Labeled text field with a big touch target.
class CtField extends StatelessWidget {
  const CtField({
    super.key,
    required this.label,
    this.controller,
    this.focusNode,
    this.hint,
    this.keyboardType,
    this.textInputAction,
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
  final FocusNode? focusNode;
  final String? hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
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
          focusNode: focusNode,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
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

/// Back guard for root screens (shell, /login, /register): Android back must
/// not quit the app on the first press. First press hints; a second press
/// within 2s exits via SystemNavigator.
class CtDoubleBackExit extends StatefulWidget {
  const CtDoubleBackExit({super.key, required this.child});

  final Widget child;

  @override
  State<CtDoubleBackExit> createState() => _CtDoubleBackExitState();
}

class _CtDoubleBackExitState extends State<CtDoubleBackExit> {
  static const _window = Duration(seconds: 2);
  DateTime? _firstPress;

  void _handlePop(bool didPop, Object? result) {
    if (didPop) return;
    final now = DateTime.now();
    if (_firstPress != null && now.difference(_firstPress!) <= _window) {
      SystemNavigator.pop();
      return;
    }
    _firstPress = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: _window,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Press back again to exit"),
              Text(
                "නැවත ආපසු ඔබන්න",
                style: TextStyle(
                  fontFamily: Ct.body,
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _handlePop,
      child: widget.child,
    );
  }
}

/// Smooth marquee text that pans horizontally if the text overflows its container bounds.
class CtMarqueeText extends StatefulWidget {
  const CtMarqueeText({
    super.key,
    required this.text,
    this.style,
    this.pauseDuration = const Duration(milliseconds: 1400),
    this.pixelsPerSecond = 35.0,
  });

  final String text;
  final TextStyle? style;
  final Duration pauseDuration;
  final double pixelsPerSecond;

  @override
  State<CtMarqueeText> createState() => _CtMarqueeTextState();
}

class _CtMarqueeTextState extends State<CtMarqueeText>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  AnimationController? _animController;
  Animation<double>? _animation;
  double _overflowDistance = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _animController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupAnimation(double distance) {
    if (_overflowDistance == distance && _animController != null) return;
    _overflowDistance = distance;
    _animController?.dispose();

    final scrollMs = ((distance / widget.pixelsPerSecond) * 1000).round();
    final pauseMs = widget.pauseDuration.inMilliseconds;
    final totalMs = (scrollMs * 2) + (pauseMs * 2);

    _animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs > 0 ? totalMs : 2000),
    );

    final pauseFrac = totalMs > 0 ? (pauseMs / totalMs) : 0.2;
    final activeFrac = 0.5 - pauseFrac;

    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0), weight: pauseFrac),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: distance)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: activeFrac,
      ),
      TweenSequenceItem(
          tween: ConstantTween<double>(distance), weight: pauseFrac),
      TweenSequenceItem(
        tween: Tween<double>(begin: distance, end: 0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: activeFrac,
      ),
    ]).animate(_animController!);

    _animation!.addListener(() {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_animation!.value);
      }
    });

    _animController!.repeat();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = widget.style ?? DefaultTextStyle.of(context).style;

    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: textStyle),
          textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
          maxLines: 1,
        )..layout();

        final textWidth = textPainter.width;
        final maxWidth = constraints.maxWidth;

        if (textWidth <= maxWidth || maxWidth.isInfinite) {
          _animController?.stop();
          return Text(
            widget.text,
            style: textStyle,
            maxLines: 1,
            overflow: TextOverflow.clip,
          );
        }

        final overflow = textWidth - maxWidth + 8.0;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _setupAnimation(overflow);
        });

        return SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Text(
            widget.text,
            style: textStyle,
            maxLines: 1,
          ),
        );
      },
    );
  }
}
