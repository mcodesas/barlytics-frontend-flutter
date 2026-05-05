import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/error_mapper.dart';
import 'crud_repository.dart';
import 'crud_state.dart';

/// Notifier genérico de estado para operaciones CRUD.
class CrudNotifier<T> extends StateNotifier<CrudState<T>> {
  CrudNotifier(this._repository) : super(const CrudState());

  final CrudRepository<T> _repository;

  Future<void> load() async {
    state = state.copyWith(loading: true);
    try {
      final items = await _repository.list();
      state = CrudState(items: items);
    } catch (error) {
      state = state.copyWith(loading: false, failure: ErrorMapper.map(error));
    }
  }

  Future<T?> findById(Object id) async {
    state = state.copyWith(loading: true);
    try {
      final item = await _repository.findById(id);
      state = state.copyWith(loading: false, selected: item);
      return item;
    } catch (error) {
      state = state.copyWith(loading: false, failure: ErrorMapper.map(error));
      return null;
    }
  }

  Future<bool> save({Object? id, required Map<String, dynamic> body}) async {
    state = state.copyWith(loading: true);
    try {
      if (id == null) {
        await _repository.create(body);
      } else {
        await _repository.update(id, body);
      }
      await load();
      return true;
    } catch (error) {
      state = state.copyWith(loading: false, failure: ErrorMapper.map(error));
      return false;
    }
  }

  Future<bool> remove(Object id) async {
    state = state.copyWith(loading: true);
    try {
      await _repository.delete(id);
      await load();
      return true;
    } catch (error) {
      state = state.copyWith(loading: false, failure: ErrorMapper.map(error));
      return false;
    }
  }
}
