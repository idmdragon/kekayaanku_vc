import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_typography.dart';
import '../application/finance_providers.dart';

/// Explains how an opening balance will be recorded: starting capital
/// before the first snapshot, a deposit after it (PRD A-14, A-42).
class OpeningNote extends ConsumerWidget {
  const OpeningNote({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final started =
        ref.watch(dashboardSummaryProvider).value?.hasSnapshot ?? false;
    return Text(
      started
          ? 'Dicatat sebagai setoran, karena pencatatan sudah berjalan. '
                'Jadi saldo ini tidak terhitung sebagai keuntungan.'
          : 'Dicatat sebagai modal awal, titik mulai perhitungan performa.',
      style: context.text.bodySmall,
    );
  }
}
