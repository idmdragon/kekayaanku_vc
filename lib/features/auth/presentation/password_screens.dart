import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/user_message.dart';
import '../application/auth_controller.dart';
import 'auth_widgets.dart';

/// Step 1 of a reset: send the email.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
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
          .sendPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _error = userMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Atur ulang kata sandi',
      subtitle:
          'Masukkan email akun Anda. Kami kirim tautan untuk membuat '
          'kata sandi baru.',
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) FormMessage.error(_error!),
              if (_sent)
                FormMessage.info(
                  'Jika ${_email.text.trim()} terdaftar, tautan sudah dikirim. '
                  'Cek juga folder spam.',
                ),
              LabeledField(
                label: 'Email',
                child: TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: validateEmail,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(hintText: 'nama@email.com'),
                ),
              ),
              BusyButton(
                label: _sent ? 'Kirim ulang' : 'Kirim tautan',
                busy: _busy,
                onPressed: _submit,
              ),
              TextButton(
                onPressed: () => context.go('/masuk'),
                child: const Text('Kembali ke halaman masuk'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Step 2: opened from the email link with a recovery session.
class UpdatePasswordScreen extends ConsumerStatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  ConsumerState<UpdatePasswordScreen> createState() =>
      _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends ConsumerState<UpdatePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
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
          .updatePassword(_password.text);
      if (mounted) context.go('/beranda');
    } catch (e) {
      if (mounted) setState(() => _error = userMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Kata sandi baru',
      subtitle: 'Buat kata sandi baru untuk akun Anda.',
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) FormMessage.error(_error!),
              LabeledField(
                label: 'Kata sandi baru (minimal $kMinPasswordLength karakter)',
                child: PasswordField(
                  controller: _password,
                  newPassword: true,
                  validator: validateNewPassword,
                ),
              ),
              LabeledField(
                label: 'Ulangi kata sandi baru',
                child: PasswordField(
                  controller: _confirm,
                  newPassword: true,
                  semanticLabel: 'Ulangi kata sandi',
                  validator: (v) =>
                      v != _password.text ? 'Kata sandi tidak sama.' : null,
                  onSubmitted: _submit,
                ),
              ),
              BusyButton(
                label: 'Simpan kata sandi',
                busy: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
