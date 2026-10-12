import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/kantong.dart';

abstract interface class KantongRepository {
  /// Active and archived kantong, in the user's order.
  Future<List<Kantong>> list();
  Future<Kantong> create(KantongDraft draft);
  Future<Kantong> update(String id, KantongDraft draft);
  Future<Kantong> setArchived(String id, {required bool archived});
  Future<void> delete(String id);
  Future<void> reorder(List<String> orderedIds);
}

class SupabaseKantongRepository implements KantongRepository {
  SupabaseKantongRepository(this._client);

  final SupabaseClient _client;

  SupabaseQueryBuilder get _table => _client.from('portfolios');

  @override
  Future<List<Kantong>> list() async {
    final rows = await _table
        .select(Kantong.columns)
        .order('sort_order')
        .order('created_at');
    return rows.map(Kantong.fromJson).toList();
  }

  @override
  Future<Kantong> create(KantongDraft draft) async => Kantong.fromJson(
    await _table.insert(draft.toJson()).select(Kantong.columns).single(),
  );

  @override
  Future<Kantong> update(String id, KantongDraft draft) async =>
      Kantong.fromJson(
        await _table
            .update(draft.toJson())
            .eq('id', id)
            .select(Kantong.columns)
            .single(),
      );

  @override
  Future<Kantong> setArchived(String id, {required bool archived}) async =>
      Kantong.fromJson(
        await _table
            .update({
              'archived_at': archived
                  ? DateTime.now().toUtc().toIso8601String()
                  : null,
            })
            .eq('id', id)
            .select(Kantong.columns)
            .single(),
      );

  @override
  Future<void> delete(String id) => _table.delete().eq('id', id);

  @override
  Future<void> reorder(List<String> orderedIds) => _client.rpc<void>(
    'reorder_portfolios',
    params: {'ordered_ids': orderedIds},
  );
}
