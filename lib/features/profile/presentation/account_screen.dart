import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/user_message.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/list_group.dart';
import '../../../shared/widgets/page_frame.dart';
import '../../../shared/widgets/top_bar.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../application/profile_controller.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authControllerProvider)?.email ?? '';
    final name = ref.watch(profileControllerProvider).value?.displayName ?? '';
    return Scaffold(
      body: PageFrame(
        header: const TopBar(title: 'Akun & keamanan', showBack: true),
        children: [
          ListGroup(
            children: [
              ListRow(
                icon: AppIcons.account,
                title: 'Nama panggilan',
                subtitle: name,
                onTap: () => showAppSheet<void>(
                  context,
                  title: 'Ubah nama panggilan',
                  builder: (_) => _NameForm(initial: name),
                ),
              ),
              ListRow(
                icon: AppIcons.password,
                title: 'Ubah kata sandi',
                subtitle: email,
                onTap: () => showAppSheet<void>(
                  context,
                  title: 'Ubah kata sandi',
                  builder: (_) => const _PasswordForm(),
                ),
              ),
            ],
          ),
          const SectionLabel('Zona berbahaya'),
          ListGroup(
            children: [
              ListRow(
                icon: AppIcons.delete,
                title: 'Hapus akun',
                subtitle: 'Menghapus akun dan semua data Anda secara permanen',
                destructive: true,
                onTap: () => showAppSheet<void>(
                  context,
                  title: 'Hapus akun',
                  builder: (_) => const _DeleteAccountForm(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NameForm extends ConsumerStatefulWidget {
  const _NameForm({required this.initial});

  final String initial;

  @override
  ConsumerState<_NameForm> createState() => _NameFormState();
}

class _NameFormState extends ConsumerState<_NameForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(profileControllerProvider.notifier)
          .setDisplayName(_name.text);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = userMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) FormMessage.error(_error!),
        LabeledField(
          label: 'Nama panggilan',
          child: TextFormField(
            controller: _name,
            autofocus: true,
            maxLength: 60,
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Isi nama panggilan.' : null,
            onFieldSubmitted: (_) => _save(),
            decoration: const InputDecoration(counterText: ''),
          ),
        ),
        BusyButton(label: 'Simpan', busy: _busy, onPressed: _save),
      ],
    ),
  );
}

class _PasswordForm extends ConsumerStatefulWidget {
  const _PasswordForm();

  @override
  ConsumerState<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends ConsumerState<_PasswordForm> {
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

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .updatePassword(_password.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kata sandi sudah diganti.')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = userMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
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
            onSubmitted: _save,
          ),
        ),
        BusyButton(label: 'Simpan kata sandi', busy: _busy, onPressed: _save),
      ],
    ),
  );
}

/// Deleting is permanent, so the user types a word to confirm.
class _DeleteAccountForm extends ConsumerStatefulWidget {
  const _DeleteAccountForm();

  @override
  ConsumerState<_DeleteAccountForm> createState() => _DeleteAccountFormState();
}

class _DeleteAccountFormState extends ConsumerState<_DeleteAccountForm> {
  static const _word = 'HAPUS';
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount();
      // Signed out now; the router returns to the sign-in screen.
    } catch (e) {
      if (mounted) setState(() => _error = userMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ready = _confirm.text.trim() == _word && !_busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Semua kantong, aset, transaksi, dan riwayat snapshot akan dihapus '
          'dan tidak bisa dikembalikan.',
          style: context.text.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.s16),
        if (_error != null) FormMessage.error(_error!),
        LabeledField(
          label: 'Ketik $_word untuk melanjutkan',
          child: TextField(
            controller: _confirm,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: c.negative,
            foregroundColor: c.bg,
          ),
          onPressed: ready ? _delete : null,
          child: Text(_busy ? 'Menghapus…' : 'Hapus akun permanen'),
        ),
      ],
    );
  }
}
