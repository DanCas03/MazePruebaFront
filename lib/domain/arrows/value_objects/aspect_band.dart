/// Single source of truth for the app-wide portrait aspect band.
///
/// A board's shape is measured as `ratio = cols / rows` under the portrait
/// convention `cols <= rows`. Boards must fall inside [minRatio, maxRatio] so
/// they fill a phone screen without large side margins. Target is 9:16.
///
/// Consumed by GeneratorConfig (runtime clamp, front#101) and by the
/// level-production ramp (campaign reshape, back#46) so both agree on one
/// number. Pure Dart — no Flutter, no external packages.
class AspectBand {
  const AspectBand._();

  /// 9:16 portrait target.
  static const double targetRatio = 9 / 16; // 0.5625

  /// Inclusive band bounds (maintainer decision 2026-07-16).
  static const double minRatio = 0.53;
  static const double maxRatio = 0.68;

  /// cols / rows. Caller guarantees rows > 0.
  static double ratioOf(int cols, int rows) => cols / rows;

  /// Whether a cols×rows shape is inside the band (edges inclusive).
  static bool contains(int cols, int rows) {
    final r = ratioOf(cols, rows);
    return r >= minRatio && r <= maxRatio;
  }

  /// Given a fixed [cols], the rows that put the shape nearest the target.
  /// For internally-suggested defaults only — never to silently rewrite
  /// explicit user input (that path rejects instead).
  static int snapRowsForCols(int cols) => (cols / targetRatio).round();
}
