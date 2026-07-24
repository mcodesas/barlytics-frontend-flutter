import '../errors/failure.dart';

/// Estado común para listados CRUD.
class CrudState<T> {
  const CrudState({
    this.items = const [],
    this.loading = false,
    this.failure,
    this.selected,
  });

  final List<T> items;
  final bool loading;
  final Failure? failure;
  final T? selected;

  CrudState<T> copyWith({List<T>? items, bool? loading, Failure? failure, T? selected}) {
    return CrudState<T>(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      failure: failure,
      selected: selected ?? this.selected,
    );
  }
}
