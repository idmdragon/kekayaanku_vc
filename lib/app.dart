import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/profile/application/profile_controller.dart';

class KekayaankuApp extends ConsumerWidget {
  const KekayaankuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider).value;
    final accent = profile?.accent ?? AppAccent.amber;
    return MaterialApp.router(
      title: 'Kekayaanku',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light, accent),
      darkTheme: buildAppTheme(Brightness.dark, accent),
      themeMode: profile?.themeMode ?? ThemeMode.system,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
