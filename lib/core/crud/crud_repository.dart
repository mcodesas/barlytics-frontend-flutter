import 'crud_remote_datasource.dart';

/// Repositorio genérico usado por los módulos CRUD.
class CrudRepository<T> {
  CrudRepository(this._remoteDataSource);

  final CrudRemoteDataSource<T> _remoteDataSource;

  Future<List<T>> list() => _remoteDataSource.list();
  Future<T> findById(Object id) => _remoteDataSource.findById(id);
  Future<T> create(Map<String, dynamic> body) => _remoteDataSource.create(body);
  Future<T> update(Object id, Map<String, dynamic> body) => _remoteDataSource.update(id, body);
  Future<void> delete(Object id) => _remoteDataSource.delete(id);
}
