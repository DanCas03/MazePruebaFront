// tool/level_production/produce_themed.dart
//
// CLI de producción de niveles temáticos (front#68). Toma máscaras `.mask`
// (ver `mask_spec.dart`) y congela un JSON arrow-path temático por figura más
// una vista previa ANSI y un manifiesto del lote. Material de curación humana:
// el curador mira `<levelId>.preview.txt` y decide si la figura se reconoce.
//
// Uso:
//   dart run tool/level_production/produce_themed.dart --mask <file.mask> [opciones]
//   dart run tool/level_production/produce_themed.dart --masks-dir <dir> [opciones]
//
// Ejemplos:
//   dart run tool/level_production/produce_themed.dart --mask masks/heart.mask
//   dart run tool/level_production/produce_themed.dart --masks-dir masks --coverage 0.85
//
// Resiliencia: cada máscara se produce en un isolate (misma disciplina que
// produce.dart). Si una máscara falla (parseo, generación, IO), se registra en
// el manifiesto y el lote CONTINÚA — el CLI nunca aborta por una máscara mala.
//
// Determinismo: mismas semillas + misma máscara ⇒ JSON idéntico (dentro de la
// misma versión del SDK de Dart; el artefacto congelado real es el JSON en git).

import 'dart:io';
import 'dart:isolate';

import 'mask_spec.dart';
import 'themed_producer.dart';

const _defaultOut = 'out/themed';
const _defaultCoverage = 0.9;
const _defaultMaxLen = 4;
const _defaultSeedStart = 0;
const _defaultSeedEnd = 49;

Future<void> main(List<String> args) async {
  final Options opts;
  try {
    opts = Options.parse(args);
  } on _UsageException catch (e) {
    stderr.writeln('Error: ${e.message}\n');
    stderr.writeln(_usage);
    exitCode = 64; // EX_USAGE
    return;
  }

  if (opts.help) {
    stdout.writeln(_usage);
    return;
  }

  final List<File> maskFiles;
  try {
    maskFiles = _resolveMaskFiles(opts);
  } on _UsageException catch (e) {
    stderr.writeln('Error: ${e.message}\n');
    stderr.writeln(_usage);
    exitCode = 64;
    return;
  }

  // Safe I/O: crea el directorio de salida (y sus padres) antes de escribir.
  final outDir = Directory(opts.out)..createSync(recursive: true);

  final seeds = [for (var s = opts.seedStart; s <= opts.seedEnd; s++) s];
  stdout.writeln('Producing ${maskFiles.length} themed mask'
      '${maskFiles.length == 1 ? '' : 's'} · '
      'mode ${opts.dense ? 'dense' : 'legacy'} · '
      'coverage target ${_pct(opts.coverage)} · maxlen ${opts.maxLen} · '
      'seeds ${opts.seedStart}..${opts.seedEnd} · out ${outDir.path}');

  final rows = StringBuffer();
  final notes = <String>[]; // regiones bajo objetivo + errores por máscara
  var produced = 0;

  for (final maskFile in maskFiles) {
    try {
      final mask = parseMaskSpec(maskFile.readAsStringSync());
      // Cada máscara en su isolate (misma disciplina que produce.dart): un
      // fallo de producción se atrapa como excepción sin tumbar el lote.
      final result = await Isolate.run(() => produceThemed(
            mask,
            coverageTarget: opts.coverage,
            maxPathLen: opts.maxLen,
            seeds: seeds,
            dense: opts.dense,
          ));

      File('${outDir.path}/${result.levelId}.json')
          .writeAsStringSync(result.json);
      File('${outDir.path}/${result.levelId}.preview.txt')
          .writeAsStringSync('${result.preview}\n');
      produced++;

      final coverageSummary = _coverageSummary(result.coveragePerRole);
      stdout.writeln(result.preview);
      stdout.writeln('  ✓ ${result.levelId}  seed ${result.seedUsed}  '
          '${result.placedArrows} arrows  $coverageSummary  '
          'target ${result.allRegionsMetTarget ? 'met' : 'NOT met'}');

      rows.writeln('| ${result.levelId} | ${mask.cols}×${mask.rows} | '
          '${result.seedUsed} | ${result.placedArrows} | $coverageSummary | '
          '${result.allRegionsMetTarget ? 'sí' : 'no'} | ninguno |');
      for (final entry in result.coveragePerRole.entries) {
        if (entry.value < opts.coverage) {
          notes.add('- ${result.levelId}: región `${entry.key}` bajo objetivo '
              '(${_pct(entry.value)} < ${_pct(opts.coverage)})');
        }
      }
    } catch (e) {
      stderr.writeln('  ✗ ${maskFile.path}  ERROR: $e');
      notes.add('- ERROR en `${maskFile.path}`: $e');
    }
  }

  _appendManifest(outDir, opts, rows, notes);

  stdout.writeln('\nProduced $produced/${maskFiles.length} themed level'
      '${maskFiles.length == 1 ? '' : 's'} to ${outDir.path} '
      '(manifest: ${outDir.path}/manifest-themed.md)');
}

/// Resuelve la lista de `.mask` a procesar según `--mask` / `--masks-dir`.
List<File> _resolveMaskFiles(Options opts) {
  if (opts.maskPath != null) {
    final file = File(opts.maskPath!);
    if (!file.existsSync()) {
      throw _UsageException('mask file not found: ${opts.maskPath}');
    }
    return [file];
  }
  final dir = Directory(opts.masksDir!);
  if (!dir.existsSync()) {
    throw _UsageException('masks dir not found: ${opts.masksDir}');
  }
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.mask'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path)); // orden estable del lote
  if (files.isEmpty) {
    throw _UsageException('no *.mask files found in ${opts.masksDir}');
  }
  return files;
}

/// Escribe/apéndice del manifiesto del lote: cada corrida agrega su propia
/// sección completa (tabla + incidencias) para que apéndices sucesivos no
/// rompan el markdown de corridas anteriores.
void _appendManifest(
    Directory outDir, Options opts, StringBuffer rows, List<String> notes) {
  final manifest = File('${outDir.path}/manifest-themed.md');
  final buf = StringBuffer();
  if (!manifest.existsSync()) {
    buf
      ..writeln('# Manifiesto de niveles temáticos (front#68)')
      ..writeln()
      ..writeln('Generado por `dart run tool/level_production/produce_themed.dart`.')
      ..writeln('Curación: revisar `<levelId>.preview.txt` para juzgar si la '
          'figura se reconoce.')
      ..writeln();
  }
  buf
    ..writeln('## Lote — modo ${opts.dense ? 'denso' : 'legacy'} · '
        'seeds ${opts.seedStart}..${opts.seedEnd} · '
        'objetivo ${_pct(opts.coverage)} · maxlen ${opts.maxLen}')
    ..writeln()
    ..writeln('| figura | dims | seed usado | flechas colocadas | '
        'cobertura por rol | objetivo alcanzado | timeLimitSec |')
    ..writeln('|---|---|---|---|---|---|---|');
  if (rows.isEmpty) {
    buf.writeln('| _(sin niveles: todas las máscaras fallaron)_ | | | | | | |');
  } else {
    buf.write(rows);
  }
  if (notes.isNotEmpty) {
    buf
      ..writeln()
      ..writeln('Incidencias (regiones bajo objetivo / errores):');
    notes.forEach(buf.writeln);
  }
  buf.writeln();
  manifest.writeAsStringSync(buf.toString(), mode: FileMode.append);
}

String _coverageSummary(Map<String, double> coveragePerRole) =>
    coveragePerRole.entries
        .map((e) => '${e.key}:${_pct(e.value)}')
        .join(' ');

String _pct(double v) => '${(v * 100).toStringAsFixed(0)}%';

/// Opciones parseadas de la línea de comandos.
class Options {
  final String? maskPath;
  final String? masksDir;
  final String out;
  final double coverage;
  final int seedStart;
  final int seedEnd;
  final int maxLen;
  final bool dense;
  final bool help;

  const Options({
    required this.maskPath,
    required this.masksDir,
    required this.out,
    required this.coverage,
    required this.seedStart,
    required this.seedEnd,
    required this.maxLen,
    required this.dense,
    required this.help,
  });

  factory Options.parse(List<String> args) {
    if (args.contains('--help') || args.contains('-h')) {
      return const Options(
          maskPath: null, masksDir: null, out: _defaultOut,
          coverage: _defaultCoverage, seedStart: _defaultSeedStart,
          seedEnd: _defaultSeedEnd, maxLen: _defaultMaxLen, dense: true,
          help: true);
    }

    final maskPath = _flag(args, '--mask');
    final masksDir = _flag(args, '--masks-dir');
    if ((maskPath == null) == (masksDir == null)) {
      throw _UsageException(
          'exactly one of --mask <file> or --masks-dir <dir> is required');
    }

    final out = _flag(args, '--out') ?? _defaultOut;

    final rawCoverage = _flag(args, '--coverage');
    final coverage =
        rawCoverage == null ? _defaultCoverage : double.tryParse(rawCoverage);
    if (coverage == null || coverage <= 0 || coverage > 1) {
      throw _UsageException(
          '--coverage must be a number in (0,1], got "$rawCoverage"');
    }

    final rawSeeds = _flag(args, '--seeds');
    final (seedStart, seedEnd) = rawSeeds == null
        ? (_defaultSeedStart, _defaultSeedEnd)
        : _parseSeeds(rawSeeds);

    final rawMaxLen = _flag(args, '--maxlen');
    final maxLen =
        rawMaxLen == null ? _defaultMaxLen : int.tryParse(rawMaxLen);
    if (maxLen == null || maxLen < 2) {
      throw _UsageException('--maxlen must be an integer >= 2, got "$rawMaxLen"');
    }

    final rawDense = _flag(args, '--dense');
    final bool dense;
    switch (rawDense) {
      case null || 'true':
        dense = true;
      case 'false':
        dense = false;
      default:
        throw _UsageException('--dense must be "true" or "false", got "$rawDense"');
    }

    return Options(
      maskPath: maskPath,
      masksDir: masksDir,
      out: out,
      coverage: coverage,
      seedStart: seedStart,
      seedEnd: seedEnd,
      maxLen: maxLen,
      dense: dense,
      help: false,
    );
  }

  static String? _flag(List<String> args, String name) {
    final i = args.indexOf(name);
    if (i < 0) return null;
    if (i + 1 >= args.length) throw _UsageException('$name requires a value');
    return args[i + 1];
  }

  /// Parsea `A..B` (rango inclusivo) o un único entero `A` (⇒ A..A).
  static (int, int) _parseSeeds(String raw) {
    if (raw.contains('..')) {
      final parts = raw.split('..');
      if (parts.length != 2) {
        throw _UsageException('--seeds range must be "A..B", got "$raw"');
      }
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);
      if (a == null || b == null) {
        throw _UsageException('--seeds bounds must be integers, got "$raw"');
      }
      if (a > b) {
        throw _UsageException('--seeds start must be <= end, got "$raw"');
      }
      return (a, b);
    }
    final single = int.tryParse(raw);
    if (single == null) {
      throw _UsageException(
          '--seeds must be "A..B" or a single integer, got "$raw"');
    }
    return (single, single);
  }
}

/// Error de uso de la CLI (argumentos inválidos): se reporta con el uso y sale
/// con código 64 (EX_USAGE), sin stack trace.
class _UsageException implements Exception {
  final String message;
  _UsageException(this.message);
}

const _usage = '''
Producción de niveles temáticos desde máscaras .mask (front#68).

Uso:
  dart run tool/level_production/produce_themed.dart --mask <file.mask> [opciones]
  dart run tool/level_production/produce_themed.dart --masks-dir <dir> [opciones]

Requeridos (exactamente uno):
  --mask <file>       Una máscara .mask concreta.
  --masks-dir <dir>   Procesa todos los *.mask del directorio.

Opciones:
  --out <dir>         Directorio de salida (se crea si no existe). Default: $_defaultOut
  --coverage <0..1>   Cobertura objetivo por región. Default: $_defaultCoverage
  --seeds <A..B>      Rango de semillas: en denso se BARRE completo y se elige
                      con el criterio de los guardianes (detalle lleno →
                      profundidad de hueco <= 2 → mayor cobertura); en legacy
                      se reintenta hasta alcanzar el objetivo. Default: $_defaultSeedStart..$_defaultSeedEnd
  --dense <bool>      Modo denso (#118): generateThemedDense + criterio de
                      selección de los guardianes. Default: true
  --maxlen <n>        Largo máximo del cuerpo de cada flecha (>= 2), SOLO en
                      modo legacy (--dense false); en denso la política de
                      longitudes está congelada con los guardianes. Default: $_defaultMaxLen
  -h, --help          Muestra esta ayuda.

Salida:
  <out>/themed-<name>.json         JSON arrow-path temático con silhouette (fill de la máscara);
                                   sin timeLimitSec: temático v1 no tiene límite.
  <out>/themed-<name>.preview.txt  Vista previa ANSI para curación (█ ocupado, ░ hueco de cobertura).
  <out>/manifest-themed.md         Manifiesto del lote (se apéndice por corrida).
''';
