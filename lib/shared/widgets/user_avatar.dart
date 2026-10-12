import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../features/profile/application/profile_controller.dart';

/// `Ilham Pratama` → `IP`, `budi` → `BU`.
String initialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return '?';
  if (words.length == 1) {
    final w = words.first;
    return w.characters.take(2).toString().toUpperCase();
  }
  return (words.first.characters.first + words.elementAt(1).characters.first)
      .toUpperCase();
}

/// The signed-in user's initials on an accent disc. Tapping opens Profil.
class UserAvatar extends ConsumerWidget {
  const UserAvatar.button({super.key})
    : size = AppLayout.avatar,
      tappable = true;
  const UserAvatar.large({super.key})
    : size = AppLayout.avatarLarge,
      tappable = false;

  final double size;
  final bool tappable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final name = ref.watch(profileControllerProvider).value?.displayName ?? '';
    final disc = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
      child: Text(
        initialsOf(name),
        style:
            (size > AppLayout.avatar
                    ? context.text.titleLarge
                    : context.text.labelMedium)
                ?.copyWith(color: c.onAccent)
                .weight(FontWeight.w700),
      ),
    );
    if (!tappable) return ExcludeSemantics(child: disc);
    return Semantics(
      button: true,
      label: 'Buka profil',
      child: SizedBox.square(
        dimension: kMinTapTarget,
        child: Center(
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push('/profil'),
              child: ExcludeSemantics(child: disc),
            ),
          ),
        ),
      ),
    );
  }
}
