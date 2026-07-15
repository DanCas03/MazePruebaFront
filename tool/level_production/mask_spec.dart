/// Themed "mask" spec parser (front#68, fragment 1).
///
/// A `.mask` file is a reviewable plain-text description of a themed level
/// mask: a `name`, a `legend` mapping single-character glyphs to semantic
/// paint roles and hex colors, and a `grid` of those glyphs. `.` is the
/// reserved background glyph (empty cell, no region).
///
/// Pure Dart, no computer vision, no new dependencies. Lives under `tool/`
/// (production tooling, outside `lib/`), importing only the domain
/// `Position` value object.
library;

import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

/// One color region of a themed mask: cells sharing one paint role.
class MaskRegion {
  final String glyph; // single char used in the grid (never '.')
  final String role; // semantic paint role -> Arrow.paintRole and palette key
  final String hex; // '#RRGGBB'
  final Set<Position> cells; // grid cells carrying this glyph

  const MaskRegion({
    required this.glyph,
    required this.role,
    required this.hex,
    required this.cells,
  });
}

/// A fully validated themed mask: name, dimensions and its color regions.
class MaskSpec {
  final String name;
  final int cols;
  final int rows;
  final List<MaskRegion> regions;

  const MaskSpec({
    required this.name,
    required this.cols,
    required this.rows,
    required this.regions,
  });

  /// role -> hex, for the level JSON `palette` field (ADR 0004).
  Map<String, String> get palette => {
        for (final r in regions) r.role: r.hex,
      };
}

/// Thrown when a `.mask` text does not conform to the format.
class MaskParseException implements Exception {
  final String message;

  const MaskParseException(this.message);

  @override
  String toString() => 'MaskParseException: $message';
}

final RegExp _hexPattern = RegExp(r'^#[0-9A-Fa-f]{6}$');

/// Parses the `.mask` text format into a validated [MaskSpec].
///
/// Format:
/// ```text
/// # comments and blank lines are ignored outside the grid
/// name: heart
/// legend:
///   H = heart : #FF4D6D
///   E = eyes : #202020
/// grid:
/// ..HH..
/// .HHHH.
/// .EHHE.
/// ```
///
/// Throws [MaskParseException] on: missing name, empty grid, non-rectangular
/// grid, unknown region glyph in the grid, invalid/missing hex, multi-char
/// legend glyph, reserved `.` in the legend, duplicate legend glyph, or a
/// legend glyph with no cells in the grid.
MaskSpec parseMaskSpec(String text) {
  final lines = text.split('\n');

  String? name;
  var inLegend = false;
  var inGrid = false;
  // Insertion-ordered so regions come out in legend order.
  final legend = <String, ({String role, String hex})>{};
  final gridRows = <String>[];

  for (final rawLine in lines) {
    // Only the trailing '\r' is stripped; grid rows are otherwise verbatim.
    final line =
        rawLine.endsWith('\r') ? rawLine.substring(0, rawLine.length - 1) : rawLine;

    if (inGrid) {
      if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
      gridRows.add(line);
      continue;
    }

    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

    if (trimmed == 'grid:') {
      inGrid = true;
      continue;
    }
    if (trimmed == 'legend:') {
      inLegend = true;
      continue;
    }
    if (trimmed.startsWith('name:')) {
      inLegend = false;
      name = trimmed.substring('name:'.length).trim();
      continue;
    }
    if (inLegend) {
      _parseLegendEntry(trimmed, legend);
      continue;
    }
    throw MaskParseException('unexpected header line: "$trimmed"');
  }

  if (name == null || name.isEmpty) {
    throw MaskParseException('missing required "name" header');
  }
  if (gridRows.isEmpty) {
    throw MaskParseException('empty grid: no grid rows found after "grid:"');
  }

  final cols = gridRows.first.length;
  for (final row in gridRows) {
    if (row.length != cols) {
      throw MaskParseException(
        'grid is not rectangular: expected $cols cols, '
        'found ${row.length} in row "$row"',
      );
    }
  }

  // Collect cells per legend glyph while validating every grid character.
  final cellsByGlyph = <String, Set<Position>>{
    for (final glyph in legend.keys) glyph: <Position>{},
  };
  for (var row = 0; row < gridRows.length; row++) {
    final line = gridRows[row];
    for (var col = 0; col < cols; col++) {
      final ch = line[col];
      if (ch == '.') continue; // reserved background: empty cell, no region
      final cells = cellsByGlyph[ch];
      if (cells == null) {
        throw MaskParseException(
          'unknown region glyph "$ch" at row $row, col $col '
          '(not declared in legend)',
        );
      }
      cells.add(Position(row: row, col: col));
    }
  }

  final regions = <MaskRegion>[];
  for (final entry in legend.entries) {
    final cells = cellsByGlyph[entry.key]!;
    if (cells.isEmpty) {
      throw MaskParseException(
        'legend glyph "${entry.key}" has no cells in the grid',
      );
    }
    regions.add(MaskRegion(
      glyph: entry.key,
      role: entry.value.role,
      hex: entry.value.hex,
      cells: cells,
    ));
  }

  return MaskSpec(
    name: name,
    cols: cols,
    rows: gridRows.length,
    regions: regions,
  );
}

/// Parses one `GLYPH = role : #RRGGBB` legend line into [legend].
void _parseLegendEntry(
  String line,
  Map<String, ({String role, String hex})> legend,
) {
  final eq = line.indexOf('=');
  if (eq < 0) {
    throw MaskParseException(
      'malformed legend entry (expected "GLYPH = role : #RRGGBB"): "$line"',
    );
  }
  final glyph = line.substring(0, eq).trim();
  final rest = line.substring(eq + 1);
  final colon = rest.lastIndexOf(':');
  if (colon < 0) {
    throw MaskParseException(
      'legend entry for "$glyph" is missing its hex color: "$line"',
    );
  }
  final role = rest.substring(0, colon).trim();
  final hex = rest.substring(colon + 1).trim();

  if (glyph == '.') {
    throw MaskParseException(
      '"." is the reserved background glyph and cannot appear in the legend',
    );
  }
  if (glyph.length != 1) {
    throw MaskParseException(
      'legend glyph must be exactly one character, got "$glyph"',
    );
  }
  if (role.isEmpty) {
    throw MaskParseException('legend entry for "$glyph" has an empty role');
  }
  if (!_hexPattern.hasMatch(hex)) {
    throw MaskParseException(
      'invalid hex color "$hex" for glyph "$glyph" (expected #RRGGBB)',
    );
  }
  if (legend.containsKey(glyph)) {
    throw MaskParseException('duplicate legend glyph "$glyph"');
  }
  legend[glyph] = (role: role, hex: hex);
}
