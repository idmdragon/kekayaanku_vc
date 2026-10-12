import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/kantong_repository.dart';
import '../domain/kantong.dart';

final kantongRepositoryProvider = Provider<KantongRepository>(
  (ref) => SupabaseKantongRepository(ref.watch(supabaseClientProvider)),
);

/// All of the user's kantong, archived ones included, in display order.
class KantongController extends AsyncNotifier<List<Kantong>> {
  KantongRepository get _repo => ref.read(kantongRepositoryProvider);

  @override
  Future<List<Kantong>> build() async {
    final userId = ref.watch(authControllerProvider.select((s) => s?.userId));
    if (userId == null) return const [];
    return ref.watch(kantongRepositoryProvider).list();
  }

  List<Kantong> get _current => state.value ?? const [];

  void _replace(Kantong k) =>
      state = AsyncData([for (final x in _current) x.id == k.id ? k : x]);

  Future<Kantong> create(KantongDraft draft) async {
    final k = await _repo.create(draft);
    if (ref.mounted) state = AsyncData([..._current, k]);
    return k;
  }

  Future<void> save(String id, KantongDraft draft) async {
    final k = await _repo.update(id, draft);
    if (ref.mounted) _replace(k);
  }

  Future<void> setArchived(String id, {required bool archived}) async {
    final k = await _repo.setArchived(id, archived: archived);
    if (ref.mounted) _replace(k);
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    if (ref.mounted) {
      state = AsyncData([
        for (final x in _current)
          if (x.id != id) x,
      ]);
    }
  }

  /// Reorders active kantong; archived ones keep their place at the end.
  Future<void> reorder(List<String> activeIds) async {
    final before = state;
    final byId = {for (final k in _current) k.id: k};
    final archived = _current.where((k) => k.archived).map((k) => k.id);
    final ids = [...activeIds, ...archived];
    state = AsyncData([for (final id in ids) byId[id]!]);
    try {
      await _repo.reorder(ids);
    } catch (_) {
      if (ref.mounted) state = before;
      rethrow;
    }
  }
}

final kantongControllerProvider =
    AsyncNotifierProvider<KantongController, List<Kantong>>(
      KantongController.new,
    );

/// One kantong by id, or `null` if it does not exist (deleted, wrong link).
final kantongByIdProvider = Provider.family<AsyncValue<Kantong?>, String>(
  (ref, id) => ref
      .watch(kantongControllerProvider)
      .whenData((list) => list.where((k) => k.id == id).firstOrNull),
);
