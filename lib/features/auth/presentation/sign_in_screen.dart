import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/user_message.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../application/auth_controller.dart';
import 'auth_widgets.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .signIn(_email.text, _password.text);
      // The router redirects once the session arrives.
    } catch (e) {
      if (mounted) setState(() => _error = userMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Masuk',
      subtitle:
          'Lihat kekayaan bersih Anda dalam rupiah, dicatat setiap hari '
          'pukul 18.00 WIB.',
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) FormMessage.error(_error!),
              LabeledField(
                label: 'Email',
                child: TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  validator: validateEmail,
                  decoration: const InputDecoration(hintText: 'nama@email.com'),
                ),
              ),
              LabeledField(
                label: 'Kata sandi',
                child: PasswordField(
                  controller: _password,
                  validator: (v) =>
                      (v ?? '').isEmpty ? 'Isi kata sandi.' : null,
                  onSubmitted: _submit,
                ),
              ),
              BusyButton(label: 'Masuk', busy: _busy, onPressed: _submit),
              const SizedBox(height: AppSpacing.s8),
              TextButton(
                onPressed: () => context.push('/lupa-sandi'),
                child: const Text('Lupa kata sandi?'),
              ),
              const SizedBox(height: AppSpacing.s16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Belum punya akun?', style: context.text.bodySmall),
                  TextButton(
                    onPressed: () => context.go('/daftar'),
                    child: const Text('Daftar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
