import 'dart:io';

/// Auditoría estática de todas las interfaces.

void main() {
  final root = Directory('lib/features');
  if (!root.existsSync()) {
    stderr.writeln('Ejecuta esto desde la raíz del repositorio Flutter.');
    exitCode = 2;
    return;
  }
  final files = root
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((f) {
        final path = f.path.replaceAll('\\', '/');
        return path.endsWith('.dart') && path.contains('/presentation/');
      }).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final modules = <String>{};
  final issues = <_Finding>[];
  var dialogs = 0, modals = 0, themeAware = 0, pages = 0;

  for (final file in files) {
    final path = file.path.replaceAll('\\', '/');
    final parts = path.split('/');
    if (parts.length > 2) modules.add(parts[2]);
    final source = file.readAsStringSync();
    final page = path.contains('/pages/') || path.contains('/screens/');
    if (page) pages++;

    final theme = source.contains('selectedAppPaletteProvider') ||
        source.contains('Theme.of(') ||
        source.contains('DynamicCrud') || source.contains('AppTheme.');
    if (theme) themeAware++;
    final publicExperience = path.contains('/public/') ||
        path.contains('/auth/') || path.contains('/eventos/') ||
        path.contains('/subscription/');
    if (page && source.length > 3000 && !theme &&
        !publicExperience && !path.endsWith('/home_page.dart')) {
      issues.add(_Finding(path, 1, 'REVISAR',
          'Pantalla especializada sin referencia a tema compartido.'));
    }

    for (final match in RegExp(r'\bAlertDialog\s*\(').allMatches(source)) {
      dialogs++;
      final end = (match.end + 450).clamp(0, source.length);
      final snippet = source.substring(match.end, end);
      final scroll = RegExp(r'\bscrollable\s*:\s*true\b').hasMatch(snippet);
      final alternative = snippet.contains('SingleChildScrollView(') ||
          snippet.contains('ListView(') ||
          (snippet.contains('ConstrainedBox(') &&
              snippet.contains('maxHeight:'));
      if (!scroll && !alternative) {
        issues.add(_Finding(path, _line(source, match.start), 'REVISAR',
            'Diálogo sin scroll declarado cerca de su inicio.'));
      }
    }

    for (final match in RegExp(r'\bshowModalBottomSheet\b').allMatches(source)) {
      modals++;
      final end = (match.end + 650).clamp(0, source.length);
      final snippet = source.substring(match.end, end);
      if (!snippet.contains('isScrollControlled: true')) {
        issues.add(_Finding(path, _line(source, match.start), 'REVISAR',
            'Modal inferior: revisar alto disponible y teclado.'));
      }
    }

    for (final match in RegExp(r'\bheight\s*:\s*([6-9][0-9]{2})\b')
        .allMatches(source)) {
      issues.add(_Finding(path, _line(source, match.start), 'INFO',
          'Altura fija de ' + (match.group(1) ?? '') + ' px.'));
    }
  }

  stdout.writeln('BARLYTICS - AUDITORÍA VISUAL DE CÓDIGO');
  stdout.writeln('Módulos: ' + modules.length.toString() +
      '; interfaces: ' + files.length.toString() +
      '; páginas: ' + pages.toString());
  stdout.writeln('Referencias a tema: ' + themeAware.toString() +
      '; diálogos: ' + dialogs.toString() +
      '; modales: ' + modals.toString());
  stdout.writeln('Revisiones sugeridas: ' + issues.length.toString());
  for (final issue in issues) {
    stdout.writeln(issue.level + ' ' + issue.path + ':' +
        issue.line.toString() + ' - ' + issue.message);
  }
  stdout.writeln('Heurístico: complementar con flutter analyze, tests y QA visual.');
}

int _line(String source, int position) =>
    '\n'.allMatches(source.substring(0, position)).length + 1;

class _Finding {
  const _Finding(this.path, this.line, this.level, this.message);
  final String path;
  final int line;
  final String level;
  final String message;
}
