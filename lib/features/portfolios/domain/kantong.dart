import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart';

import '../../../core/theme/app_colors.dart';

/// Emoji suggestions in the kantong editor (docs/design-system.md 6.1).
const kKantongEmoji = [
  '📈',
  '⚡',
  '🪙',
  '🥇',
  '🛟',
  '🏠',
  '🎓',
  '✈️',
  '💍',
  '🚗',
  '🌱',
  '🏦',
  '💼',
  '🎯',
  '🧧',
  '🐷',
];

const int kKantongNameMax = 28;
const int kKantongNoteMax = 280;

/// Card figures for one kantong. All zero until slice 2 brings holdings and
/// the valuation RPC; they are never computed in Dart.
@immutable
class KantongFigures {
  const KantongFigures({
    required this.value,
    required this.cost,
    required this.unrealized,
    required this.cash,
    required this.assetCount,
  });

  static final KantongFigures empty = KantongFigures(
    value: Decimal.zero,
    cost: Decimal.zero,
    unrealized: Decimal.zero,
    cash: Decimal.zero,
    assetCount: 0,
  );

  final Decimal value;
  final Decimal cost;
  final Decimal unrealized;
  final Decimal cash;
  final int assetCount;
}

/// What the editor produces; also the writable columns of `portfolios`.
@immutable
class KantongDraft {
  const KantongDraft({
    this.name = '',
    this.emoji = '💼',
    this.color = KantongColor.langit,
    this.cashEnabled = true,
    this.note = '',
  });

  final String name;
  final String emoji;
  final KantongColor color;
  final bool cashEnabled;
  final String note;

  KantongDraft copyWith({
    String? name,
    String? emoji,
    KantongColor? color,
    bool? cashEnabled,
    String? note,
  }) => KantongDraft(
    name: name ?? this.name,
    emoji: emoji ?? this.emoji,
    color: color ?? this.color,
    cashEnabled: cashEnabled ?? this.cashEnabled,
    note: note ?? this.note,
  );

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'emoji': emoji,
    'color_key': color.name,
    'cash_enabled': cashEnabled,
    'note': note.trim().isEmpty ? null : note.trim(),
  };
}

/// Row of `public.portfolios`, shown to the user as a "kantong".
@immutable
class Kantong {
  Kantong({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    required this.cashEnabled,
    required this.note,
    required this.sortOrder,
    required this.archivedAt,
    required this.createdAt,
    KantongFigures? figures,
  }) : figures = figures ?? KantongFigures.empty;

  factory Kantong.fromJson(Map<String, dynamic> j) => Kantong(
    id: j['id'] as String,
    name: j['name'] as String,
    emoji: j['emoji'] as String,
    color: KantongColor.values.byName(j['color_key'] as String),
    cashEnabled: j['cash_enabled'] as bool,
    note: j['note'] as String?,
    sortOrder: j['sort_order'] as int,
    archivedAt: j['archived_at'] == null
        ? null
        : DateTime.parse(j['archived_at'] as String),
    createdAt: DateTime.parse(j['created_at'] as String),
  );

  static const columns =
      'id, name, emoji, color_key, cash_enabled, note, sort_order, '
      'archived_at, created_at';

  final String id;
  final String name;
  final String emoji;
  final KantongColor color;
  final bool cashEnabled;
  final String? note;
  final int sortOrder;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final KantongFigures figures;

  bool get archived => archivedAt != null;

  KantongDraft toDraft() => KantongDraft(
    name: name,
    emoji: emoji,
    color: color,
    cashEnabled: cashEnabled,
    note: note ?? '',
  );
}

String? validateKantongName(String? v) {
  final s = v?.trim() ?? '';
  if (s.isEmpty) return 'Beri nama kantong.';
  if (s.characters.length > kKantongNameMax) {
    return 'Maksimal $kKantongNameMax karakter.';
  }
  return null;
}
