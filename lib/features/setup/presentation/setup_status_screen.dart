import 'package:flutter/material.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';

/// Shown instead of the app when the build has no Supabase configuration.
class SetupStatusScreen extends StatelessWidget {
  const SetupStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.gutterMobile),
              children: [
                Text('Kekayaanku', style: text.headlineMedium),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  'Aplikasi belum terhubung ke database. Isi URL dan '
                  'publishable key Supabase, lalu jalankan ulang.',
                  style: text.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.s24),
                _StatusRow(
                  icon: AppIcons.check,
                  color: c.positive,
                  label: 'Tema, huruf Geist, dan ikon',
                  detail: 'Token dari design system',
                ),
                _StatusRow(
                  icon: Env.hasSupabase ? AppIcons.check : AppIcons.warning,
                  color: Env.hasSupabase ? c.positive : c.warning,
                  label: 'Koneksi Supabase',
                  detail: Env.hasSupabase
                      ? 'Terkonfigurasi'
                      : 'Belum dikonfigurasi. Jalankan dengan '
                            '--dart-define-from-file=dart_defines.json',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.detail,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.titleMedium),
                Text(detail, style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
