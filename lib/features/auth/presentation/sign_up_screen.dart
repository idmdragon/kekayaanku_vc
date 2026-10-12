import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/user_message.dart';
import '../../../core/theme/app_typography.dart';
import '../application/auth_controller.dart';
import '../data/auth_repository.dart';
import 'auth_widgets.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _sentTo;

  @override
  void dispose() {
    _name.dispose();
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
      final outcome = await ref
          .read(authControllerProvider.notifier)
          .signUp(_email.text, _password.text, _name.text);
      if (outcome == SignUpOutcome.confirmEmail && mounted) {
        setState(() => _sentTo = _email.text.trim());
      }
    } catch (e) {
      if (mounted) setState(() => _error = userMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sentTo != null) {
      return AuthScaffold(
        title: 'Cek email Anda',
        subtitle:
            'Kami mengirim tautan konfirmasi ke $_sentTo. Buka tautan '
            'itu, lalu masuk dengan email dan kata sandi yang baru dibuat.',
        children: [
          FilledButton(
            onPressed: () => context.go('/masuk'),
            child: const Text('Ke halaman masuk'),
          ),
        ],
      );
    }

    return AuthScaffold(
      title: 'Buat akun',
      subtitle:
          'Satu akun untuk web dan ponsel. Data Anda hanya bisa dibaca '
          'oleh akun Anda sendiri.',
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) FormMessage.error(_error!),
              LabeledField(
                label: 'Nama panggilan',
                child: TextFormField(
                  controller: _name,
                  autofillHints: const [AutofillHints.givenName],
                  textInputAction: TextInputAction.next,
                  maxLength: 60,
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Isi nama panggilan.' : null,
                  decoration: const InputDecoration(
                    hintText: 'mis. Ilham',
                    counterText: '',
                  ),
                ),
              ),
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
                label: 'Kata sandi (minimal $kMinPasswordLength karakter)',
                child: PasswordField(
                  controller: _password,
                  newPassword: true,
                  validator: validateNewPassword,
                  onSubmitted: _submit,
                ),
              ),
              BusyButton(label: 'Daftar', busy: _busy, onPressed: _submit),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Sudah punya akun?', style: context.text.bodySmall),
                  TextButton(
                    onPressed: () => context.go('/masuk'),
                    child: const Text('Masuk'),
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
