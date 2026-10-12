import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/user_message.dart';
import '../../../core/format/date.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/list_group.dart';
import '../../../shared/widgets/page_frame.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/top_bar.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../application/profile_controller.dart';
import '../domain/profile.dart';

void showError(BuildContext context, Object e) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(userMessage(e))));

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider);
    return Scaffold(
      body: PageFrame(
        header: const TopBar(title: 'Profil', showBack: true),
        children: profile.when(
          loading: () => const [
            LoadingRegion(child: Skeleton(height: AppLayout.skeletonHero)),
          ],
          error: (e, _) => [
            ErrorPanel(
              what: 'Profil gagal dimuat.',
              error: e,
              onRetry: () => ref.invalidate(profileControllerProvider),
            ),
          ],
          data: (p) => [
            if (p != null) _Header(profile: p),
            const SectionLabel('Aplikasi'),
            ListGroup(
              children: [
                ListRow(
                  icon: AppIcons.appearance,
                  title: 'Tampilan',
                  subtitle: 'Tema dan warna aksen',
                  onTap: p == null
                      ? null
                      : () => showAppSheet<void>(
                          context,
                          title: 'Tampilan',
                          builder: (_) => const AppearanceSheet(),
                        ),
                ),
                ListRow(
                  icon: AppIcons.account,
                  title: 'Akun & keamanan',
                  subtitle: 'Nama, kata sandi, hapus akun',
                  onTap: () => context.push('/profil/akun'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            _SignOutButton(),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authControllerProvider)?.email ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
      child: Column(
        children: [
          const UserAvatar.large(),
          const SizedBox(height: AppSpacing.s8),
          Text(profile.displayName, style: context.text.titleLarge),
          Text(email, style: context.text.bodySmall),
          Text(
            'Tracking sejak ${formatDateShort(profile.trackingStartedOn)}',
            style: context.text.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SignOutButton extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends ConsumerState<_SignOutButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.negative,
        side: BorderSide(color: c.line),
        minimumSize: const Size.fromHeight(kMinTapTarget),
        shape: const StadiumBorder(),
      ),
      onPressed: _busy
          ? null
          : () async {
              setState(() => _busy = true);
              try {
                await ref.read(authControllerProvider.notifier).signOut();
              } catch (e) {
                if (context.mounted) showError(context, e);
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
      icon: const Icon(AppIcons.signOut),
      label: const Text('Keluar'),
    );
  }
}

/// Theme mode and accent (docs/design-system.md DS-6, DS-7).
class AppearanceSheet extends ConsumerWidget {
  const AppearanceSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileControllerProvider).value;
    if (p == null) return const SizedBox.shrink();
    final ctrl = ref.read(profileControllerProvider.notifier);
    final c = context.colors;

    void guard(Future<void> f) => f.catchError(
      (Object e) => context.mounted ? showError(context, e) : null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tema', style: context.text.labelMedium),
        const SizedBox(height: AppSpacing.s8),
        SegmentedButton<ThemeMode>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: ThemeMode.system,
              icon: Icon(AppIcons.themeSystem),
              label: Text('Sistem'),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              icon: Icon(AppIcons.themeLight),
              label: Text('Terang'),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              icon: Icon(AppIcons.themeDark),
              label: Text('Gelap'),
            ),
          ],
          selected: {p.themeMode},
          onSelectionChanged: (s) => guard(ctrl.setThemeMode(s.first)),
        ),
        const SizedBox(height: AppSpacing.s16),
        Text('Warna aksen', style: context.text.labelMedium),
        const SizedBox(height: AppSpacing.s8),
        RadioGroup<AppAccent>(
          groupValue: p.accent,
          onChanged: (v) => guard(ctrl.setAccent(v!)),
          child: Column(
            children: [
              for (final a in AppAccent.values)
                RadioListTile<AppAccent>(
                  value: a,
                  contentPadding: EdgeInsets.zero,
                  activeColor: c.accent,
                  title: Text(_accentLabel(a), style: context.text.bodyMedium),
                  secondary: Container(
                    width: AppLayout.emojiBoxSmall,
                    height: AppLayout.emojiBoxSmall,
                    decoration: BoxDecoration(
                      color: _swatch(context, a),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static Color _swatch(BuildContext context, AppAccent a) =>
      (Theme.of(context).brightness == Brightness.dark
              ? AppColors.dark(a)
              : AppColors.light(a))
          .accent;

  static String _accentLabel(AppAccent a) => switch (a) {
    AppAccent.amber => 'Amber (bawaan)',
    AppAccent.lime => 'Lime',
    AppAccent.blue => 'Biru',
  };
}
