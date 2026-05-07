import 'crud_repository.dart';

class ListCrudItems<T> {
  const ListCrudItems(this._repository);
  final CrudRepository<T> _repository;
  Future<List<T>> call() => _repository.list();
}

class GetCrudItem<T> {
  const GetCrudItem(this._repository);
  final CrudRepository<T> _repository;
  Future<T> call(Object id) => _repository.findById(id);
}

class CreateCrudItem<T> {
  const CreateCrudItem(this._repository);
  final CrudRepository<T> _repository;
  Future<T> call(Map<String, dynamic> body) => _repository.create(body);
}

class UpdateCrudItem<T> {
  const UpdateCrudItem(this._repository);
  final CrudRepository<T> _repository;
  Future<T> call(Object id, Map<String, dynamic> body) => _repository.update(id, body);
}

class DeleteCrudItem<T> {
  const DeleteCrudItem(this._repository);
  final CrudRepository<T> _repository;
  Future<void> call(Object id) => _repository.delete(id);
}
