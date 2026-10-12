import 'package:flutter/material.dart';

import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/page_frame.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/top_bar.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: PageFrame(
      header: TopBar(title: 'Riwayat', showAvatar: true),
      children: [
        EmptyState(
          icon: AppIcons.history,
          title: 'Belum ada snapshot',
          message:
              'Setiap hari pukul 18.00 WIB kekayaan Anda dicatat permanen. '
              'Daftar snapshot tampil di sini.',
        ),
      ],
    ),
  );
}

/// Perlu perhatian: stale prices, maturing deposits, failed snapshots.
class AttentionScreen extends StatelessWidget {
  const AttentionScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: PageFrame(
      header: TopBar(title: 'Perlu perhatian', showBack: true),
      children: [
        EmptyState(
          icon: AppIcons.check,
          title: 'Semua aman',
          message:
              'Tidak ada harga basi, deposito jatuh tempo, atau snapshot '
              'yang gagal.',
        ),
      ],
    ),
  );
}
