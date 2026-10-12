import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Frame shared by the sign-in, sign-up and password screens.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.gutterMobile),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.formMaxWidth,
              ),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: AppLayout.emojiBoxSmall,
                          height: AppLayout.emojiBoxSmall,
                          decoration: BoxDecoration(
                            color: c.accent,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Icon(
                            AppIcons.wallet,
                            color: c.onAccent,
                            size: AppLayout.iconSize,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s12),
                        Text('Kekayaanku', style: context.text.titleMedium),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s32),
                    Semantics(
                      header: true,
                      child: Text(title, style: context.text.headlineMedium),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Text(
                      subtitle,
                      style: context.text.bodyMedium?.copyWith(color: c.muted),
                    ),
                    const SizedBox(height: AppSpacing.s24),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Labelled text field with the app's spacing.
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.s16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: context.text.labelMedium),
        const SizedBox(height: AppSpacing.s8),
        child,
      ],
    ),
  );
}

/// Password input with a show/hide toggle.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.validator,
    this.newPassword = false,
    this.onSubmitted,
    this.semanticLabel = 'Kata sandi',
  });

  final TextEditingController controller;
  final FormFieldValidator<String>? validator;
  final bool newPassword;
  final VoidCallback? onSubmitted;
  final String semanticLabel;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _hidden,
      validator: widget.validator,
      autofillHints: [
        widget.newPassword ? AutofillHints.newPassword : AutofillHints.password,
      ],
      textInputAction: widget.onSubmitted == null
          ? TextInputAction.next
          : TextInputAction.done,
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      decoration: InputDecoration(
        hintText: widget.semanticLabel,
        suffixIcon: IconButton(
          tooltip: _hidden ? 'Tampilkan kata sandi' : 'Sembunyikan kata sandi',
          icon: Icon(_hidden ? AppIcons.show : AppIcons.hide),
          onPressed: () => setState(() => _hidden = !_hidden),
        ),
      ),
    );
  }
}

/// Form-level message: an error in `negative`, or a confirmation.
class FormMessage extends StatelessWidget {
  const FormMessage.error(this.text, {super.key}) : isError = true;
  const FormMessage.info(this.text, {super.key}) : isError = false;

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.s16),
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          color: isError ? c.surface : c.positiveSoft,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: isError ? Border.all(color: c.negative) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? AppIcons.warning : AppIcons.check,
              size: AppLayout.iconSize,
              color: isError ? c.negative : c.positive,
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(child: Text(text, style: context.text.bodyMedium)),
          ],
        ),
      ),
    );
  }
}

/// Primary button that shows a spinner and blocks taps while [busy].
class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? SizedBox.square(
              dimension: AppLayout.iconSize,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: c.muted,
                semanticsLabel: 'Memproses',
              ),
            )
          : Text(label),
    );
  }
}
