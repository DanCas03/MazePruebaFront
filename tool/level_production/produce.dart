// tool/level_production/produce.dart
//
// CLI de producción de candidatos de nivel (front#65). Corre la Rampa de
// dificultad (ver `ramp.dart`) sobre un rango de semillas y congela un JSON
// arrow-path por candidato más un manifiesto del lote. Material de curación
// humana: se generan candidatos trazables (`cand-tN-sNNN`) y una persona elige
// 15 finales (5 tiers × 3) sobre la campaña.
//
// Uso:
//   dart run tool/level_production/produce.dart --tier <1..5> --seeds <A..B> \
//       [--out <dir>] [--finale] [--budget <segundos>]
//
// Ejemplos:
//   dart run tool/level_production/produce.dart --tier 3 --seeds 300..309
//   dart run tool/level_production/produce.dart --tier 5 --finale --seeds 900..909
//
// Resiliencia: cada semilla se genera en un isolate con presupuesto de tiempo
// (--budget, 5 s por defecto). Si una semilla excede el tiempo o falla la
// validación, se registra en el manifiesto de errores y el lote CONTINÚA — el
// CLI nunca aborta por una semilla mala.
//
// Determinismo: misma semilla + mismos parámetros ⇒ JSON idéntico (dentro de la
// misma versión del SDK de Dart; el artefacto congelado real es el JSON en git).

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'candidate_producer.dart';
import 'ramp.dart';
import 'validation.dart';

const _defaultOut = 'out/candidates';
const _defaultBudgetSec = 5;

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

  final step = rampStepFor(opts.tier, finale: opts.finale);

  // Safe I/O: crea el directorio de salida (y sus padres) si no existe, antes
  // de escribir nada.
  final outDir = Directory(opts.out)..createSync(recursive: true);

  final label = opts.finale ? 't${step.tier}-finale' : 't${step.tier}';
  final manifest = _Manifest(step: step);
  final errors = _ErrorManifest();

  stdout.writeln(
      'Producing tier ${step.tier}${opts.finale ? ' (finale, 50×50)' : ''} · '
      '${step.cols}×${step.rows} · fill ${step.fillRatio} · '
      'arrows ${step.arrowCount} · '
      '${step.timeLimitSec == null ? 'untimed' : 'timeLimit ${step.timeLimitSec}s'} · '
      'seeds ${opts.seedStart}..${opts.seedEnd} · budget ${opts.budgetSec}s');

  var produced = 0;
  var degraded = 0;

  for (var seed = opts.seedStart; seed <= opts.seedEnd; seed++) {
    final spec = CandidateSpec(step: step, seed: seed);
    try {
      // Cada semilla en su isolate con timeout: así una generación que se
      // pasa del presupuesto se puede atrapar (el código síncrono no se puede
      // interrumpir de otra forma) sin tumbar el lote.
      final result = await Isolate.run(() => produceCandidate(spec))
          .timeout(Duration(seconds: opts.budgetSec));

      File('${outDir.path}/${result.levelId}.json').writeAsStringSync(result.json);
      manifest.addRow(result);
      produced++;
      if (result.placedArrows < result.requestedArrows) degraded++;
      stdout.writeln(
          '  ✓ ${result.levelId}  ${result.placedArrows}/${result.requestedArrows} arrows  '
          'density ${result.achievedDensity.toStringAsFixed(2)}  ${result.durationMs}ms');
    } on TimeoutException {
      errors.add(spec, 'exceeded ${opts.budgetSec}s time budget');
      stderr.writeln('  ✗ ${spec.levelId}  TIMEOUT (> ${opts.budgetSec}s)');
    } on CandidateValidationException catch (e) {
      errors.add(spec, 'validation failed: ${e.message}');
      stderr.writeln('  ✗ ${spec.levelId}  INVALID: ${e.message}');
    } catch (e) {
      errors.add(spec, 'unexpected error: $e');
      stderr.writeln('  ✗ ${spec.levelId}  ERROR: $e');
    }
  }

  File('${outDir.path}/manifest-$label.md').writeAsStringSync(manifest.render());
  if (errors.isNotEmpty) {
    File('${outDir.path}/errors-$label.md').writeAsStringSync(errors.render(label));
  }

  final total = opts.seedEnd - opts.seedStart + 1;
  stdout.writeln(
      '\nTier ${step.tier}: produced $produced/$total candidates '
      '(${errors.length} error${errors.length == 1 ? '' : 's'}, $degraded degraded) '
      'to ${outDir.path}');
  if (errors.isNotEmpty) {
    stdout.writeln('See ${outDir.path}/errors-$label.md for the error manifest.');
  }
}

/// Opciones parseadas de la línea de comandos.
class Options {
  final int tier;
  final int seedStart;
  final int seedEnd;
  final String out;
  final bool finale;
  final int budgetSec;
  final bool help;

  const Options({
    required this.tier,
    required this.seedStart,
    required this.seedEnd,
    required this.out,
    required this.finale,
    required this.budgetSec,
    required this.help,
  });

  factory Options.parse(List<String> args) {
    if (args.contains('--help') || args.contains('-h')) {
      return const Options(
          tier: 1, seedStart: 0, seedEnd: 0, out: _defaultOut,
          finale: false, budgetSec: _defaultBudgetSec, help: true);
    }

    final tier = _requireInt(_flag(args, '--tier'), '--tier');
    if (tier < minTier || tier > maxTier) {
      throw _UsageException('--tier must be between $minTier and $maxTier, got $tier');
    }
    final finale = args.contains('--finale');
    if (finale && tier != maxTier) {
      throw _UsageException('--finale is only valid with --tier $maxTier (the 50×50 level 15)');
    }

    final range = _parseSeeds(_flag(args, '--seeds'));
    final out = _flag(args, '--out') ?? _defaultOut;
    final budget = _flag(args, '--budget');
    final budgetSec = budget == null ? _defaultBudgetSec : _requireInt(budget, '--budget');
    if (budgetSec < 1) {
      throw _UsageException('--budget must be a positive number of seconds, got $budgetSec');
    }

    return Options(
      tier: tier,
      seedStart: range.$1,
      seedEnd: range.$2,
      out: out,
      finale: finale,
      budgetSec: budgetSec,
      help: false,
    );
  }

  static String? _flag(List<String> args, String name) {
    final i = args.indexOf(name);
    if (i < 0) return null;
    if (i + 1 >= args.length) throw _UsageException('$name requires a value');
    return args[i + 1];
  }

  static int _requireInt(String? raw, String name) {
    if (raw == null) throw _UsageException('$name is required');
    final v = int.tryParse(raw);
    if (v == null) throw _UsageException('$name must be an integer, got "$raw"');
    return v;
  }

  /// Parsea `A..B` (rango inclusivo) o un único entero `A` (⇒ A..A).
  static (int, int) _parseSeeds(String? raw) {
    if (raw == null) throw _UsageException('--seeds is required (e.g. 300..309)');
    if (raw.contains('..')) {
      final parts = raw.split('..');
      if (parts.length != 2) throw _UsageException('--seeds range must be "A..B", got "$raw"');
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);
      if (a == null || b == null) throw _UsageException('--seeds bounds must be integers, got "$raw"');
      if (a > b) throw _UsageException('--seeds start must be <= end, got "$raw"');
      return (a, b);
    }
    final single = int.tryParse(raw);
    if (single == null) throw _UsageException('--seeds must be "A..B" or a single integer, got "$raw"');
    return (single, single);
  }
}

/// Manifiesto del lote exitoso: una fila por candidato escrito.
class _Manifest {
  final RampStep step;
  final StringBuffer _rows = StringBuffer();
  var _any = false;

  _Manifest({required this.step});

  void addRow(CandidateResult r) {
    _any = true;
    final flag = r.placedArrows < r.requestedArrows ? ' (!)' : '';
    _rows.writeln(
        '| ${r.levelId} | ${r.tier} | ${r.cols}×${r.rows} | '
        '${r.placedArrows}/${r.requestedArrows}$flag | '
        '${r.achievedDensity.toStringAsFixed(2)} | '
        '${step.timeLimitSec ?? '—'} | ${r.durationMs} |');
  }

  String render() {
    final buf = StringBuffer()
      ..writeln('# Candidatos — tier ${step.tier}${step.finale ? ' (remate 50×50)' : ''}')
      ..writeln()
      ..writeln('Generado por `dart run tool/level_production/produce.dart` (front#65).')
      ..writeln('Rampa: ${step.cols}×${step.rows} · fillRatio ${step.fillRatio} · '
          'maxPathLen ${step.maxPathLen} · '
          '${step.timeLimitSec == null ? 'sin límite' : 'timeLimit ${step.timeLimitSec}s'}.')
      ..writeln('Material de curación: elegir los finales sobre estos candidatos trazables.')
      ..writeln('`(!)` = degradación con gracia (el generador colocó menos flechas de las pedidas).')
      ..writeln()
      ..writeln('| candidato | tier | dims | flechas (colocadas/pedidas) | densidad | timeLimitSec | duración (ms) |')
      ..writeln('|---|---|---|---|---|---|---|');
    if (_any) {
      buf.write(_rows.toString());
    } else {
      buf.writeln('| _(sin candidatos: todos fallaron, ver errors)_ | | | | | | |');
    }
    return buf.toString();
  }
}

/// Manifiesto de errores: semillas que excedieron el tiempo o fallaron la
/// validación. Solo se escribe si hubo al menos un error.
class _ErrorManifest {
  final List<({String levelId, int tier, int seed, String reason})> _entries = [];

  void add(CandidateSpec spec, String reason) => _entries.add((
        levelId: spec.levelId,
        tier: spec.step.tier,
        seed: spec.seed,
        reason: reason,
      ));

  bool get isNotEmpty => _entries.isNotEmpty;
  int get length => _entries.length;

  String render(String label) {
    final buf = StringBuffer()
      ..writeln('# Manifiesto de errores — $label')
      ..writeln()
      ..writeln('Semillas que no produjeron candidato (excedieron el presupuesto de tiempo o '
          'fallaron la validación). El lote continuó pese a estas.')
      ..writeln()
      ..writeln('| candidato | tier | seed | motivo |')
      ..writeln('|---|---|---|---|');
    for (final e in _entries) {
      buf.writeln('| ${e.levelId} | ${e.tier} | ${e.seed} | ${e.reason} |');
    }
    return buf.toString();
  }
}

/// Error de uso de la CLI (argumentos inválidos): se reporta con el uso y sale
/// con código 64 (EX_USAGE), sin stack trace.
class _UsageException implements Exception {
  final String message;
  _UsageException(this.message);
}

const _usage = '''
Producción de candidatos de nivel (front#65).

Uso:
  dart run tool/level_production/produce.dart --tier <1..5> --seeds <A..B> [opciones]

Requeridos:
  --tier <1..5>     Tier de la Rampa a producir.
  --seeds <A..B>    Rango inclusivo de semillas (p.ej. 300..309), o un único entero.

Opciones:
  --out <dir>       Directorio de salida (se crea si no existe). Default: $_defaultOut
  --finale          Solo con --tier 5: produce el remate 50×50 (nivel 15) en vez de 42×46.
  --budget <seg>    Presupuesto de tiempo por semilla en segundos. Default: $_defaultBudgetSec
  -h, --help        Muestra esta ayuda.

Salida:
  <out>/cand-tN-sNNN.json   Un JSON arrow-path por candidato.
  <out>/manifest-tN.md      Manifiesto del lote (dims, flechas, densidad, duración).
  <out>/errors-tN.md        Manifiesto de errores (solo si alguna semilla falló).
''';
