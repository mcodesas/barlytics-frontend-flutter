import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/error_mapper.dart';
import 'crud_repository.dart';
import 'crud_state.dart';

/// Notifier genérico de estado para operaciones CRUD.
///
/// Las operaciones remotas pueden terminar después de que un provider
/// `autoDispose` haya sido destruido (por ejemplo, al navegar rápidamente
/// entre pantallas). Por eso toda escritura de estado posterior a un `await`
/// debe comprobar [mounted] antes de tocar [state].
class CrudNotifier<T> extends StateNotifier<CrudState<T>> {
  CrudNotifier(this._repository) : super(const CrudState());

  final CrudRepository<T> _repository;

  Future<void> load() async {
    if (!mounted) return;
    state = state.copyWith(loading: true);
    try {
      final items = await _repository.list();
      if (!mounted) return;
      state = CrudState(items: items);
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(loading: false, failure: ErrorMapper.map(error));
    }
  }

  Future<T?> findById(Object id) async {
    if (!mounted) return null;
    state = state.copyWith(loading: true);
    try {
      final item = await _repository.findById(id);
      if (!mounted) return null;
      state = state.copyWith(loading: false, selected: item);
      return item;
    } catch (error) {
      if (!mounted) return null;
      state = state.copyWith(loading: false, failure: ErrorMapper.map(error));
      return null;
    }
  }

  Future<bool> save({Object? id, required Map<String, dynamic> body}) async {
    final result = await saveAndReturn(id: id, body: body);
    return result != null;
  }

  Future<T?> saveAndReturn({Object? id, required Map<String, dynamic> body}) async {
    if (!mounted) return null;
    state = state.copyWith(loading: true);
    try {
      final saved = id == null ? await _repository.create(body) : await _repository.update(id, body);
      if (!mounted) return null;
      await load();
      if (!mounted) return null;
      return saved;
    } catch (error) {
      if (!mounted) return null;
      state = state.copyWith(loading: false, failure: ErrorMapper.map(error));
      return null;
    }
  }

  Future<bool> remove(Object id) async {
    if (!mounted) return false;
    state = state.copyWith(loading: true);
    try {
      await _repository.delete(id);
      if (!mounted) return false;
      await load();
      if (!mounted) return false;
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(loading: false, failure: ErrorMapper.map(error));
      return false;
    }
  }
}
