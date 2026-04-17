import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/design_system.dart';

/// Reusable text input with design system styling.
class GsField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType inputType;
  final List<TextInputFormatter>? formatters;
  final bool obscure;

  const GsField({
    super.key,
    required this.label,
    required this.controller,
    this.hint = '',
    this.inputType = TextInputType.text,
    this.formatters,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: GsTypography.label),
        const SizedBox(height: GsSpacing.xs),
        TextFormField(
          controller: controller,
          keyboardType: inputType,
          inputFormatters: formatters,
          obscureText: obscure,
          style: GsTypography.body.copyWith(color: GsColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GsTypography.body.copyWith(color: GsColors.textTertiary),
            filled: true,
            fillColor: GsColors.card,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: GsSpacing.md, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: GsShapes.sm,
              borderSide: const BorderSide(color: GsColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: GsShapes.sm,
              borderSide: const BorderSide(color: GsColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: GsShapes.sm,
              borderSide: const BorderSide(color: GsColors.accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// Reusable dropdown with design system styling.
class GsDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const GsDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: GsTypography.label),
        const SizedBox(height: GsSpacing.xs),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          style: GsTypography.body.copyWith(color: GsColors.textPrimary),
          dropdownColor: GsColors.card,
          decoration: InputDecoration(
            filled: true,
            fillColor: GsColors.card,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: GsSpacing.md, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: GsShapes.sm,
              borderSide: const BorderSide(color: GsColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: GsShapes.sm,
              borderSide: const BorderSide(color: GsColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: GsShapes.sm,
              borderSide: const BorderSide(color: GsColors.accent, width: 1.5),
            ),
          ),
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                    e[0].toUpperCase() + e.substring(1),
                    style: GsTypography.body.copyWith(color: GsColors.textPrimary),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

/// Standard CTA button.
class GsButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color color;
  final Color textColor;
  final IconData? icon;

  const GsButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.color = GsColors.primary,
    this.textColor = Colors.white,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: GsShapes.md,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: GsShapes.md,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 18, color: textColor),
                        const SizedBox(width: GsSpacing.sm),
                      ],
                      Text(label, style: GsTypography.button.copyWith(color: textColor)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Compatibility wrapper for previous GsGradientButton usage
class GsGradientButton extends StatelessWidget {
  final String label;
  final LinearGradient? gradient;
  final VoidCallback? onPressed;
  final bool isLoading;

  const GsGradientButton({
    super.key,
    required this.label,
    this.gradient,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GsButton(
      label: label,
      onPressed: onPressed,
      isLoading: isLoading,
    );
  }
}

/// Generic content card.
class GsCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Border? border;

  const GsCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(GsSpacing.md),
      decoration: BoxDecoration(
        color: color ?? GsColors.card,
        borderRadius: GsShapes.md,
        boxShadow: GsShadows.subtle,
        border: border,
      ),
      child: child,
    );
  }
}

/// Section label.
class GsSectionLabel extends StatelessWidget {
  final String text;
  const GsSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: GsSpacing.sm),
      child: Text(text.toUpperCase(), style: GsTypography.label),
    );
  }
}
