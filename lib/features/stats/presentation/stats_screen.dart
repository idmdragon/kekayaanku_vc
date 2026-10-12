import 'package:flutter/material.dart';

import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/page_frame.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/top_bar.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: PageFrame(
      header: TopBar(title: 'Statistik', showAvatar: true),
      children: [
        EmptyState(
          icon: AppIcons.stats,
          title: 'Belum ada statistik',
          message:
              'Realized dan unrealized P/L per rentang waktu tampil di sini '
              'setelah Anda mencatat jual beli.',
        ),
      ],
    ),
  );
}
