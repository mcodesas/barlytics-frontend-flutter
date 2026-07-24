/// Implementación de respaldo para plataformas no contempladas por las
/// importaciones condicionales.
class SecureStorageService {
  final Map<String, String> _memory = <String, String>{};

  Future<String?> read(String key) async => _memory[key];

  Future<void> write(String key, String value) async {
    _memory[key] = value;
  }

  Future<void> delete(String key) async {
    _memory.remove(key);
  }

  Future<void> clear() async {
    _memory.clear();
  }
}
